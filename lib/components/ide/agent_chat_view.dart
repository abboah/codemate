import 'dart:convert';

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
  
  // Local state for optimistic UI updates for new chats
  List<AgentChatMessage> _localMessages = [];
  bool _isSendingNewChat = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();

    if (_activeChatId == null) {
      // This is the first message of a new chat
      _startNewChat(text);
    } else {
      // This is an existing chat
      ref.read(agentChatProvider(_activeChatId!).notifier).sendMessage(
            text: text,
            model: _selectedModel,
          );
    }
  }

  Future<void> _startNewChat(String text) async {
    setState(() {
      _isSendingNewChat = true;
      final userMessage = AgentChatMessage(id: 'local_user', chatId: '', sender: MessageSender.user, messageType: AgentMessageType.text, content: text, sentAt: DateTime.now());
      final aiPlaceholder = AgentChatMessage(id: 'local_ai', chatId: '', sender: MessageSender.ai, messageType: AgentMessageType.text, content: '...', sentAt: DateTime.now());
      _localMessages = [userMessage, aiPlaceholder];
    });

    String fullResponse = '';
    try {
      final chatService = ref.read(chatServiceProvider);
      final stream = chatService.sendMessage(text, [], 'You are Robin...', model: _selectedModel);

      await for (var chunk in stream) {
        fullResponse += chunk;
        setState(() {
          _localMessages[1] = _localMessages[1].copyWith(content: fullResponse);
        });
      }

      // Now that we have the full response, create the chat and save messages
      final title = await chatService.generateChatTitle(text, fullResponse);
      
      final chatResponse = await Supabase.instance.client.from('agent_chats').insert({
        'project_id': widget.projectId,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'title': title
      }).select('id').single();
      
      final newChatId = chatResponse['id'];

      await Supabase.instance.client.from('agent_chat_messages').insert([
        {
          'chat_id': newChatId,
          'sender': 'user',
          'message_type': 'text',
          'content': text,
        },
        {
          'chat_id': newChatId,
          'sender': 'ai',
          'message_type': 'text',
          'content': fullResponse,
        }
      ]);

      _handleToolCall(fullResponse);

      setState(() {
        _activeChatId = newChatId;
        _localMessages = [];
        _isSendingNewChat = false;
      });
      ref.invalidate(projectChatsProvider(widget.projectId));

    } catch (e) {
      setState(() {
        _localMessages[1] = _localMessages[1].copyWith(content: "Sorry, an error occurred.");
        _isSendingNewChat = false;
      });
    }
  }

  void _handleToolCall(String response) async {
    try {
      final decodedResponse = jsonDecode(response);
      if (decodedResponse is Map<String, dynamic> && decodedResponse.containsKey('tool_code')) {
        final toolCode = decodedResponse['tool_code'];
        final args = decodedResponse['args'] as Map<String, dynamic>;
        final filesNotifier = ref.read(projectFilesProvider(widget.projectId).notifier);

        final toolMessage = AgentChatMessage(
          id: 'local_tool',
          chatId: '',
          sender: MessageSender.ai,
          messageType: AgentMessageType.toolInProgress,
          content: 'Executing tool: $toolCode...',
          sentAt: DateTime.now(),
        );
        setState(() {
          _localMessages.add(toolMessage);
        });

        try {
          switch (toolCode) {
            case 'file_system.create_file':
              await filesNotifier.createFile(args['path'], args['content']);
              break;
            case 'file_system.update_file':
              await filesNotifier.updateFileContent(args['file_id'], args['content']);
              break;
            case 'file_system.delete_file':
              await filesNotifier.deleteFile(args['file_id']);
              break;
          }
          setState(() {
            final index = _localMessages.indexWhere((m) => m.id == 'local_tool');
            if (index != -1) {
              _localMessages[index] = toolMessage.copyWith(
                messageType: AgentMessageType.toolResult,
                content: 'Tool executed successfully.',
              );
            }
          });
        } catch (e) {
          setState(() {
            final index = _localMessages.indexWhere((m) => m.id == 'local_tool');
            if (index != -1) {
              _localMessages[index] = toolMessage.copyWith(
                messageType: AgentMessageType.error,
                content: 'Error executing tool: $e',
              );
            }
          });
        }
      }
    } catch (e) {
      // Not a tool call, ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatHistory = ref.watch(projectChatsProvider(widget.projectId));

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildChatHeader(theme, chatHistory),
          Expanded(
            child: _activeChatId == null
                ? _buildInitialOrLocalView()
                : Consumer(
                    builder: (context, ref, child) {
                      final chatState = ref.watch(agentChatProvider(_activeChatId!));
                      if (chatState.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        reverse: true,
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final messages = chatState.messages.reversed.toList();
                          final message = messages[index];
                          final isLast = index == 0;
                          return AgentMessageBubble(
                            message: message,
                            isLastMessage: isLast,
                          );
                        },
                      );
                    },
                  ),
          ),
          _buildChatInput(theme, _isSendingNewChat || (_activeChatId != null && ref.watch(agentChatProvider(_activeChatId!)).isSending)),
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
        final isLast = index == 0;
        return AgentMessageBubble(
          message: message,
          isLastMessage: isLast,
        );
      },
    );
  }

  Widget _buildChatHeader(ThemeData theme, AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    // ... (same as before)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Robin',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New Chat',
                onPressed: () => setState(() {
                  _activeChatId = null;
                  _localMessages = [];
                }),
              ),
              IconButton(
                icon: const Icon(Icons.save_alt_outlined),
                tooltip: 'Create Checkpoint',
                onPressed: () {},
              ),
              chatHistory.when(
                data: (history) => PopupMenuButton<String>(
                  tooltip: 'Chat History',
                  icon: const Icon(Icons.manage_history),
                  onSelected: (value) => setState(() {
                    _activeChatId = value;
                    _localMessages = [];
                  }),
                  itemBuilder: (BuildContext context) => history
                      .map((chat) => PopupMenuItem<String>(
                            value: chat['id'],
                            child: Text(chat['title'] ?? 'Chat'),
                          ))
                      .toList(),
                ),
                loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
                error: (err, stack) => const Icon(Icons.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView() {
    // ... (same as before)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Start building with Robin',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          _SuggestionChip(
            text: 'Create a basic Flutter project structure',
            onTap: () {
              _controller.text = 'Create a basic Flutter project structure';
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
          _SuggestionChip(
            text: 'Explain how to set up a Supabase backend',
            onTap: () {
              _controller.text = 'Explain how to set up a Supabase backend';
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(ThemeData theme, bool isSending) {
    // ... (same as before)
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: TextField(
              controller: _controller,
              style: TextStyle(color: theme.colorScheme.onSurface),
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Message Robin...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: () {}),
                  // Placeholder for Agent/Chat toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'agent', label: Text('Agent')),
                      ButtonSegment(value: 'chat', label: Text('Chat')),
                    ],
                    selected: const {'agent'},
                    onSelectionChanged: (val) {},
                  ),
                ],
              ),
              Row(
                children: [
                  _buildModelToggle(),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: seaBlue),
                    icon: isSending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward),
                    onPressed: isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelToggle() {
    // ... (same as before)
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedModel = value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'gemini-2.5-flash', child: Text('Gemini 2.5 Pro')),
        const PopupMenuItem(value: 'gemini-2.5-flash-lite', child: Text('Gemini 2.5 Flash')),
      ],
      child: Row(
        children: [
          Text(
            _selectedModel == 'gemini-2.5-flash' ? 'Gemini 2.5 Pro' : 'Gemini 2.5 Flash',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
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
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(text, textAlign: TextAlign.center),
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
    final theme = Theme.of(context);
    final isUser = message.sender == MessageSender.user;
    final isTool = message.messageType != AgentMessageType.text;

    if (isTool) {
      return _buildToolMessage(theme, message);
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: isUser ? seaBlue : theme.colorScheme.surfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
              ),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: MarkdownBody(
                data: message.content,
                selectable: true,
                builders: {
                  'pre': CodeBlockBuilder(),
                  'code': InlineCodeBuilder(),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: GoogleFonts.poppins(color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant),
                  h1: GoogleFonts.poppins(color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  h2: GoogleFonts.poppins(color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  h3: GoogleFonts.poppins(color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  code: GoogleFonts.robotoMono(backgroundColor: Colors.black.withOpacity(0.2), color: Colors.white),
                ),
              ),
            ),
          ),
          if (!isUser && isLastMessage)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: IconButton(
                icon: const Icon(Icons.copy, color: Colors.grey, size: 18),
                tooltip: 'Copy Message',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard!'),
                      backgroundColor: seaBlue,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolMessage(ThemeData theme, AgentChatMessage message) {
    String text;
    Widget icon;

    switch (message.messageType) {
      case AgentMessageType.toolInProgress:
        text = message.content;
        icon = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
        break;
      case AgentMessageType.toolResult:
        text = 'Tool execution finished.';
        icon = const Icon(Icons.check_circle, color: Colors.green);
        break;
      case AgentMessageType.error:
        text = 'Error executing tool.';
        icon = const Icon(Icons.error, color: Colors.red);
        break;
      default:
        text = message.content;
        icon = const Icon(Icons.build);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
