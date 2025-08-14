import 'dart:convert';
import 'dart:ui';

import 'package:codemate/components/ide/code_block_builder.dart';
import 'package:codemate/components/ide/inline_code_builder.dart';
import 'package:codemate/models/agent_chat_message.dart';
import 'package:codemate/providers/agent_chat_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:codemate/components/ide/diff_preview.dart';
import 'package:codemate/components/ide/edit_summary.dart';

class AgentChatView extends ConsumerStatefulWidget {
  final String projectId;
  const AgentChatView({super.key, required this.projectId});

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  final TextEditingController _controller = TextEditingController();
  String? _activeChatId;
  String _selectedModel = 'gemini-2.5-flash';

  List<AgentChatMessage> _localMessages = [];
  bool _isSendingNewChat = false;

  @override
  void initState() {
    super.initState();
    _loadLatestChat();
  }

  Future<void> _loadLatestChat() {
    setState(() {
      _activeChatId = null;
      _localMessages = [];
    });
    return Future.value();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();

    if (_activeChatId == null) {
      _startNewChat(text);
    } else {
      ref.read(agentChatProvider(_activeChatId!).notifier).sendMessage(
            text: text,
            model: _selectedModel,
            projectId: widget.projectId,
          );
    }
  }

  Future<void> _startNewChat(String text) async {
    setState(() {
      _isSendingNewChat = true;
      final userMessage = AgentChatMessage(id: 'local_user_${const Uuid().v4()}', chatId: '', sender: MessageSender.user, messageType: AgentMessageType.text, content: text, sentAt: DateTime.now());
      final aiPlaceholder = AgentChatMessage(id: 'local_ai_${const Uuid().v4()}', chatId: '', sender: MessageSender.ai, messageType: AgentMessageType.toolInProgress, content: 'Robin is thinking...', sentAt: DateTime.now());
      _localMessages = [userMessage, aiPlaceholder];
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'agent-handler',
        body: {'prompt': text, 'history': [], 'projectId': widget.projectId, 'model': _selectedModel},
      );

      if (response.status != 200) throw Exception('Backend function failed: ${response.data}');

      final result = response.data as Map<String, dynamic>;
      final aiResponseContent = result['text'] as String? ?? '';
      final fileEdits = (result['fileEdits'] as List<dynamic>?) ?? [];

      final chatService = ref.read(chatServiceProvider);
      final title = await chatService.generateChatTitle(text, aiResponseContent);

      final chatResponse = await Supabase.instance.client.from('agent_chats').insert({
        'project_id': widget.projectId,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'title': title
      }).select('id').single();

      final newChatId = chatResponse['id'];

      final aiMessage = AgentChatMessage(
        id: const Uuid().v4(),
        chatId: newChatId,
        sender: MessageSender.ai,
        messageType: AgentMessageType.text,
        content: '',
        toolResults: {'fileEdits': fileEdits},
        sentAt: DateTime.now(),
      );

      setState(() => _localMessages[1] = aiMessage);

      const chunkSize = 24;
      for (int i = 0; i < aiResponseContent.length; i += chunkSize) {
        final end = (i + chunkSize < aiResponseContent.length) ? i + chunkSize : aiResponseContent.length;
        setState(() {
          _localMessages[1] = _localMessages[1].copyWith(
            content: _localMessages[1].content + aiResponseContent.substring(i, end),
          );
        });
        await Future.delayed(const Duration(milliseconds: 12));
      }

      await Supabase.instance.client.from('agent_chat_messages').insert([
        {'chat_id': newChatId, 'sender': 'user', 'message_type': 'text', 'content': text},
        {
          'chat_id': newChatId,
          'sender': 'ai',
          'message_type': 'text',
          'content': _localMessages[1].content,
          'tool_results': {'fileEdits': fileEdits},
        },
      ]);

      ref.read(projectFilesProvider(widget.projectId).notifier).fetchFiles();
      ref.invalidate(projectChatsProvider(widget.projectId));

      setState(() {
        _activeChatId = newChatId;
        _localMessages = [];
        _isSendingNewChat = false;
      });
    } catch (e) {
      setState(() {
        _localMessages[1] = _localMessages[1].copyWith(
          content: "Sorry, an error occurred: $e",
          messageType: AgentMessageType.error,
        );
        _isSendingNewChat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSending = _isSendingNewChat || (_activeChatId != null && ref.watch(agentChatProvider(_activeChatId!)).isSending);
    final chatHistory = ref.watch(projectChatsProvider(widget.projectId));

    return Column(
      children: [
        _buildChatHeader(chatHistory),
        Expanded(
          child: _activeChatId == null
              ? _buildInitialOrLocalView()
              : Consumer(
                  builder: (context, ref, child) {
                    final chatState = ref.watch(agentChatProvider(_activeChatId!));
                    if (chatState.isLoading && chatState.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      reverse: true,
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final messages = chatState.messages.reversed.toList();
                        final message = messages[index];
                        return Padding(
                          key: ValueKey(message.id),
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: AgentMessageBubble(
                            message: message,
                            isLastMessage: index == 0,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        _buildChatInput(isSending),
      ],
    );
  }

  Widget _buildChatHeader(AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 8.0, left: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70),
            tooltip: 'New Chat',
            onPressed: () => setState(() {
              _activeChatId = null;
              _localMessages = [];
            }),
          ),
          const SizedBox(width: 4),
          chatHistory.when(
            data: (history) => PopupMenuButton<String>(
              tooltip: 'Chat History',
              icon: const Icon(Icons.manage_history_rounded, color: Colors.white70),
              onSelected: (value) => setState(() {
                _activeChatId = value;
                _localMessages = [];
              }),
              color: const Color(0xFF1E1E1E),
              itemBuilder: (BuildContext context) => history
                  .map((chat) => PopupMenuItem<String>(
                        value: chat['id'],
                        child: Text(
                          chat['title'] ?? 'Untitled Chat',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ))
                  .toList(),
            ),
            loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, stack) => const Icon(Icons.error, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialOrLocalView() {
    if (_localMessages.isEmpty) {
      return _buildInitialView();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      reverse: true,
      itemCount: _localMessages.length,
      itemBuilder: (context, index) {
        final messages = _localMessages.reversed.toList();
        final message = messages[index];
        return Padding(
          key: ValueKey(message.id),
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: AgentMessageBubble(
            message: message,
            isLastMessage: index == 0,
          ),
        );
      },
    );
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: Colors.blueAccent.withOpacity(0.8), size: 48),
          const SizedBox(height: 24),
          Text(
            'Start building with Robin',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Describe what you want to build, ask a question, or give an instruction.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          _SuggestionChip(
            text: 'Create a basic project structure',
            onTap: () {
              _controller.text = 'Create a basic project structure for this app.';
              _sendMessage();
            },
          ),
          _SuggestionChip(
            text: 'Add a login page with email and password fields',
            onTap: () {
              _controller.text = 'Add a login page with email and password fields';
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(bool isSending) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 8,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Message Robin…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Attach File',
                          icon: Icon(Icons.attach_file, color: Colors.white.withOpacity(0.7)),
                          onPressed: () {},
                        ),
                        _buildModelToggle(),
                      ],
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.arrow_upward, color: Colors.white),
                      onPressed: isSending ? null : _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelToggle() {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedModel = value),
      color: const Color(0xFF1E1E1E),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'gemini-2.5-flash', child: Text('Gemini 2.5 Flash', style: GoogleFonts.poppins(color: Colors.white))),
        PopupMenuItem(value: 'gemini-2.5-flash-lite', child: Text('Gemini 2.5 Flash Lite', style: GoogleFonts.poppins(color: Colors.white))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              _selectedModel == 'gemini-2.5-flash' ? 'Gemini 2.5 Flash' : 'Gemini 2.5 Flash Lite',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.white70),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8)),
        ),
      ),
    );
  }
}

class AgentMessageBubble extends StatelessWidget {
  final AgentChatMessage message;
  final bool isLastMessage;

  const AgentMessageBubble({
    super.key,
    required this.message,
    this.isLastMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final isTool = message.messageType != AgentMessageType.text;

    if (isTool) {
      return _buildToolMessage(message);
    }

    final List<dynamic> edits = (message.toolResults != null && message.toolResults is Map && (message.toolResults as Map)["fileEdits"] is List)
        ? List<dynamic>.from((message.toolResults as Map)["fileEdits"] as List)
        : [];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: isUser ? Colors.blueAccent : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
              ),
              border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (edits.isNotEmpty && !isUser) ...[
                  EditsSummary(fileEdits: edits),
                  const SizedBox(height: 8),
                  ...edits.map((e) => DiffPreview(
                        path: (e['path'] as String?) ?? 'unknown',
                        oldContent: (e['old_content'] as String?) ?? '',
                        newContent: (e['new_content'] as String?) ?? '',
                      )),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                ],
                MarkdownBody(
                  data: message.content,
                  selectable: true,
                  builders: {
                    'pre': CodeBlockBuilder(),
                    'code': InlineCodeBuilder(),
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: GoogleFonts.poppins(color: Colors.white, fontSize: 15, height: 1.6),
                    h1: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    h2: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    h3: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                    code: GoogleFonts.robotoMono(
                      backgroundColor: Colors.black.withOpacity(0.3),
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      border: Border(left: BorderSide(color: Colors.white.withOpacity(0.2), width: 4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isUser && isLastMessage)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: IconButton(
                icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                tooltip: 'Copy Message',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard!'),
                      backgroundColor: Colors.blueAccent,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolMessage(AgentChatMessage message) {
    String text;
    Widget icon;

    switch (message.messageType) {
      case AgentMessageType.toolInProgress:
        text = message.content;
        icon = const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70));
        break;
      case AgentMessageType.toolResult:
        text = 'Tool execution finished.';
        icon = const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18);
        break;
      case AgentMessageType.error:
        text = 'Error executing tool.';
        icon = const Icon(Icons.error, color: Colors.redAccent, size: 18);
        break;
      default:
        text = message.content;
        icon = const Icon(Icons.build, size: 18, color: Colors.white70);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
