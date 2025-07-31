import 'dart:ui';
import 'package:codemate/models/project.dart';
import 'package:codemate/providers/active_chat_provider.dart';
import 'package:codemate/providers/agent_chat_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AgentView extends ConsumerWidget {
  final Project project;
  const AgentView({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChatId = ref.watch(activeChatProvider);
    final chatProvider = ref.watch(agentChatProvider((activeChatId, project)));
    final chatNotifier =
        ref.read(agentChatProvider((activeChatId, project)).notifier);

    final chatContent = Column(
      children: [
        Expanded(
          child: chatProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : chatProvider.error != null
                  ? Center(child: Text('Error: ${chatProvider.error}'))
                  : chatProvider.messages.isEmpty
                      ? _InitialChatView(
                          onSend: (text) => chatNotifier.sendMessage(text),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: chatProvider.messages.length,
                          itemBuilder: (context, index) {
                            final message = chatProvider.messages[index];
                            final isStreaming =
                                index == chatProvider.messages.length - 1 &&
                                    chatProvider.isGenerating;
                            return MessageBubble(
                              message: message,
                              isStreaming: isStreaming,
                            );
                          },
                        ),
        ),
        if (chatProvider.messages.isNotEmpty)
          ChatInputBar(
            enabled: !chatProvider.isGenerating,
            onSend: (text, file) {
              String messageText = text;
              if (file != null) {
                messageText +=
                    "\n\n--- Attached File: ${file.name} ---\n\n${String.fromCharCodes(file.bytes!)}";
              }
              chatNotifier.sendMessage(messageText);
            },
          ),
      ],
    );

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
        ),
        child: chatContent,
      ),
    );
  }
}

class _InitialChatView extends StatelessWidget {
  final Function(String) onSend;
  const _InitialChatView({required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Image.asset('assets/images/projectx_logo.png', height: 80),
        const SizedBox(height: 24),
        Text(
          "Hello, I'm Robin",
          style: GoogleFonts.poppins(
            fontSize: 42,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your AI pair programmer. What are we building today?",
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 32),
        ChatInputBar(onSend: (text, file) => onSend(text)),
        const SizedBox(height: 24),
        SuggestedPrompts(onSend: onSend),
        const Spacer(),
      ],
    );
  }
}

class SuggestedPrompts extends StatelessWidget {
  final Function(String) onSend;
  const SuggestedPrompts({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final prompts = [
      "Create a basic Flutter project structure",
      "What's the best way to manage state?",
      "Write a login screen UI",
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: prompts
          .map((prompt) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ActionChip(
                  label: Text(prompt),
                  onPressed: () => onSend(prompt),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ))
          .toList(),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final AgentChatMessage message;
  final bool isStreaming;
  const MessageBubble(
      {super.key, required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              backgroundImage: AssetImage('assets/images/projectx_logo.png'),
              radius: 16,
            ),
          if (!isUser) const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color:
                    isUser ? Colors.blueAccent : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: isStreaming && message.content.isEmpty
                  ? const TypingIndicator()
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.poppins(color: Colors.white, height: 1.5),
                        code: GoogleFonts.robotoMono(
                            backgroundColor: Colors.black.withOpacity(0.2)),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            const CircleAvatar(
              backgroundImage: AssetImage('assets/images/avatar.png'),
              radius: 16,
            ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  _TypingIndicatorState createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(0.1 * index, 0.5 + 0.1 * index,
                    curve: Curves.easeInOut),
              ),
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Interval(0.1 * index, 0.5 + 0.1 * index,
                      curve: Curves.easeInOut),
                ),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ChatInputBar extends StatefulWidget {
  final Function(String, PlatformFile?) onSend;
  final bool enabled;
  const ChatInputBar({super.key, required this.onSend, this.enabled = true});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  PlatformFile? _attachedFile;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true, // Important to read file content
    );

    if (result != null) {
      setState(() {
        _attachedFile = result.files.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.5,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_attachedFile != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attachment_rounded,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(_attachedFile!.name,
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 16),
                            onPressed: () =>
                                setState(() => _attachedFile = null),
                          )
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: 10,
                      minLines: 1,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type your message to Robin...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded),
                            onPressed: _pickFile,
                            color: Colors.white70,
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic_rounded),
                            onPressed: () {
                              // TODO: Implement voice input
                            },
                            color: Colors.white70,
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_controller.text.isNotEmpty ||
                              _attachedFile != null) {
                            widget.onSend(_controller.text, _attachedFile);
                            _controller.clear();
                            setState(() {
                              _attachedFile = null;
                            });
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}