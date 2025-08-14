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
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/components/ide/attach_code_dialog.dart';
import 'package:codemate/providers/diff_overlay_provider.dart';

class AgentChatView extends ConsumerStatefulWidget {
  final String projectId;
  const AgentChatView({super.key, required this.projectId});

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  String? _activeChatId;
  String _selectedModel = 'gemini-2.5-flash';
  bool _askMode = false; // false = Agent, true = Ask

  List<AgentChatMessage> _localMessages = [];
  bool _isSendingNewChat = false;

  // Attachments state: list of maps { path, content, file_id }
  List<Map<String, dynamic>> _attachedFiles = [];

  // Mentions state
  bool _showMentions = false;
  String _mentionQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLatestChat();
    _controller.addListener(_handleTextChangedForMentions);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChangedForMentions);
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
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

    final attachmentsToSend = List<Map<String, dynamic>>.from(_attachedFiles);
    setState(() {
      _attachedFiles = [];
      _showMentions = false;
      _mentionQuery = '';
    });

    if (_activeChatId == null) {
      _startNewChat(text, attachmentsToSend);
    } else {
      ref.read(agentChatProvider(_activeChatId!).notifier).sendMessage(
            text: text,
            model: _selectedModel,
            projectId: widget.projectId,
            attachedFiles: attachmentsToSend,
            useAskHandler: _askMode,
          );
    }
  }

  Future<void> _startNewChat(String text, List<Map<String, dynamic>> attachments) async {
    setState(() {
      _isSendingNewChat = true;
      final userMessage = AgentChatMessage(id: 'local_user_${const Uuid().v4()}', chatId: '', sender: MessageSender.user, messageType: AgentMessageType.text, content: text, attachedFiles: attachments, sentAt: DateTime.now());
      final aiPlaceholder = AgentChatMessage(id: 'local_ai_${const Uuid().v4()}', chatId: '', sender: MessageSender.ai, messageType: AgentMessageType.toolInProgress, content: 'Robin is thinking...', sentAt: DateTime.now());
      _localMessages = [userMessage, aiPlaceholder];
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        _askMode ? 'agent-chat-handler' : 'agent-handler',
        body: {'prompt': text, 'history': [], 'projectId': widget.projectId, 'model': _selectedModel, 'attachedFiles': attachments},
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

      // Ensure correct ordering by explicit sent_at values
      final sentAtUser = DateTime.now();
      final sentAtAi = sentAtUser.add(const Duration(milliseconds: 10)); // Add 10ms

      await Supabase.instance.client.from('agent_chat_messages').insert([
        {
          'chat_id': newChatId,
          'sender': 'user',
          'message_type': 'text',
          'content': text,
          'attached_files': attachments,
          'sent_at': sentAtUser.toIso8601String(),
        },
        {
          'chat_id': newChatId,
          'sender': 'ai',
          'message_type': 'text',
          'content': _localMessages[1].content,
          'tool_results': {'fileEdits': fileEdits},
          'sent_at': sentAtAi.toIso8601String(),
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

  void _handleTextChangedForMentions() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final cursor = selection.baseOffset;
    final beforeCursor = cursor > 0 ? text.substring(0, cursor) : '';
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    // Ensure there is no whitespace between @ and cursor
    final mentionCandidate = beforeCursor.substring(atIndex);
    final valid = RegExp(r'^@[^\s@]*$');
    if (valid.hasMatch(mentionCandidate)) {
      final query = mentionCandidate.substring(1);
      setState(() {
        _mentionQuery = query;
        _showMentions = true;
      });
    } else {
      if (_showMentions) setState(() => _showMentions = false);
    }
  }

  void _addAttachments(List<Map<String, dynamic>> files) {
    final byPath = {for (final f in _attachedFiles) f['path']: f};
    for (final f in files) {
      byPath[f['path']] = f;
    }
    setState(() => _attachedFiles = byPath.values.toList());
  }

  void _removeAttachmentByPath(String path) {
    setState(() => _attachedFiles.removeWhere((f) => f['path'] == path));
  }

  void _insertMentionAndAttach(Map<String, dynamic> file) {
    // Replace current @query with @file.path
    final text = _controller.text;
    final selection = _controller.selection;
    final cursor = selection.baseOffset;
    final beforeCursor = cursor > 0 ? text.substring(0, cursor) : '';
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex != -1) {
      final mentionText = '@' + (file['path'] as String);
      final newText = text.substring(0, atIndex) + mentionText + text.substring(cursor);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: atIndex + mentionText.length),
      );
    }
    _addAttachments([file]);
    setState(() {
      _showMentions = false;
      _mentionQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSending = _isSendingNewChat || (_activeChatId != null && ref.watch(agentChatProvider(_activeChatId!)).isSending);
    final chatHistory = ref.watch(projectChatsProvider(widget.projectId));
    final projectFilesState = ref.watch(projectFilesProvider(widget.projectId));

    final files = projectFilesState.files;
    final mentionResults = _showMentions
        ? files
            .where((f) => _mentionQuery.isEmpty || f.path.toLowerCase().contains(_mentionQuery.toLowerCase()))
            .take(8)
            .map((f) => {'path': f.path, 'content': f.content, 'file_id': f.id})
            .toList()
        : const <Map<String, dynamic>>[];

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
                            projectId: widget.projectId,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        _buildChatInput(isSending, mentionResults),
      ],
    );
  }

  Widget _buildChatHeader(AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 8.0, left: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: chatHistory.when(
              data: (history) {
                String title = 'New Chat';
                if (_activeChatId != null) {
                  final item = history.firstWhere((h) => h['id'] == _activeChatId, orElse: () => {});
                  if (item.isNotEmpty) {
                    title = item['title'] ?? 'Untitled Chat';
                  }
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ),
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
            projectId: widget.projectId,
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

  Widget _buildChatInput(bool isSending, List<Map<String, dynamic>> mentionResults) {
    final filesProvider = ref.read(projectFilesProvider(widget.projectId).notifier);

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
                // Mode toggle pills
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ModePill(
                            label: 'Agent',
                            selected: !_askMode,
                            onTap: () => setState(() => _askMode = false),
                          ),
                          _ModePill(
                            label: 'Ask',
                            selected: _askMode,
                            onTap: () => setState(() => _askMode = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_attachedFiles.isNotEmpty)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _attachedFiles
                          .map((f) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.description_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      f['path'] as String,
                                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _removeAttachmentByPath(f['path'] as String),
                                      child: const Icon(Icons.close, color: Colors.white60, size: 14),
                                    )
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                if (_showMentions && mentionResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: mentionResults.length,
                      itemBuilder: (context, index) {
                        final item = mentionResults[index];
                        return InkWell(
                          onTap: () => _insertMentionAndAttach(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.description_outlined, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['path'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Shortcuts(
                  shortcuts: <LogicalKeySet, Intent>{
                    LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<Intent>(
                        onInvoke: (intent) {
                          if (_showMentions && mentionResults.isNotEmpty) {
                            _insertMentionAndAttach(mentionResults.first);
                          }
                          return null;
                        },
                      ),
                    },
                    child: TextField(
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
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Add',
                          onSelected: (value) async {
                            if (value == 'attach_code') {
                              final selected = await showDialog<List<Map<String, dynamic>>>(
                                context: context,
                                builder: (context) => AttachCodeDialog(projectId: widget.projectId, initiallySelectedPaths: _attachedFiles.map((e) => e['path'] as String).toList()),
                              );
                              if (selected != null && selected.isNotEmpty) {
                                _addAttachments(selected);
                              }
                            } else if (value == 'upload_file') {
                              // TODO: Implement upload flow later
                            }
                          },
                          color: const Color(0xFF1E1E1E),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'attach_code',
                              child: Row(
                                children: [
                                  const Icon(Icons.code, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Attach code', style: GoogleFonts.poppins(color: Colors.white)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'upload_file',
                              child: Row(
                                children: [
                                  const Icon(Icons.upload_file, color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Upload file', style: GoogleFonts.poppins(color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add_circle_outline, color: Colors.white.withOpacity(0.7)),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildModelToggle(),
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

class AgentMessageBubble extends ConsumerWidget {
  final AgentChatMessage message;
  final bool isLastMessage;
  final String projectId;

  const AgentMessageBubble({
    super.key,
    required this.message,
    required this.projectId,
    this.isLastMessage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.sender == MessageSender.user;
    final isTool = message.messageType != AgentMessageType.text;

    if (isTool) {
      return _buildToolMessage(message);
    }

    final List<dynamic> edits = (message.toolResults != null && message.toolResults is Map && (message.toolResults as Map)["fileEdits"] is List)
        ? List<dynamic>.from((message.toolResults as Map)["fileEdits"] as List)
        : [];

    final List<dynamic> attached = message.attachedFiles is List ? List<dynamic>.from(message.attachedFiles as List) : [];

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
                  ...edits.map((e) {
                    final path = (e['path'] as String?) ?? 'unknown';
                    return InkWell(
                      onTap: () {
                        try {
                          final files = ref.read(projectFilesProvider(projectId)).files;
                          final file = files.firstWhere((f) => f.path == path);
                          ref.read(codeViewProvider.notifier).openFile(file);
                          ref.read(diffOverlayProvider).showOverlay(
                                path: path,
                                oldContent: (e['old_content'] as String?) ?? '',
                                newContent: (e['new_content'] as String?) ?? '',
                              );
                          // Expand file tree to this path
                          _expandFileTreeToPath(ref, projectId, path);
                        } catch (_) {}
                      },
                      child: DiffPreview(
                        path: path,
                        oldContent: (e['old_content'] as String?) ?? '',
                        newContent: (e['new_content'] as String?) ?? '',
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                ],
                if (isUser && attached.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attached.map((a) {
                      final path = a['path'] as String? ?? 'unknown';
                      final content = a['content'] as String? ?? '';
                      final preview = content.split('\n').take(5).join('\n');
                      return InkWell(
                        onTap: () {
                          final files = ref.read(projectFilesProvider(projectId)).files;
                          final file = files.firstWhere((f) => f.path == path, orElse: () => throw Exception('File not found'));
                          ref.read(codeViewProvider.notifier).openFile(file);
                          _expandFileTreeToPath(ref, projectId, path);
                          // Optionally navigate to editor tab if needed; Build page layout likely already shows editor
                        },
                        child: Container(
                          width: 320,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description_outlined, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(path, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  preview,
                                  style: GoogleFonts.robotoMono(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
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
                  const SizedBox(width: 4),
                  _FeedbackButton(
                    icon: Icons.thumb_up_alt_outlined,
                    selected: message.feedback == 'like',
                    onTap: () async {
                      // Optimistic UI update
                      message.feedback == 'like';
                      await Supabase.instance.client
                          .from('agent_chat_messages')
                          .update({'feedback': 'like'})
                          .eq('id', message.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback'),
                          backgroundColor: Colors.grey.withOpacity(0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  _FeedbackButton(
                    icon: Icons.thumb_down_alt_outlined,
                    selected: message.feedback == 'dislike',
                    onTap: () async {
                      // Optimistic UI update
                      message.feedback == 'dislike';
                      await Supabase.instance.client
                          .from('agent_chat_messages')
                          .update({'feedback': 'dislike'})
                          .eq('id', message.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback'),
                          backgroundColor: Colors.grey.withOpacity(0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
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

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
}

void _expandFileTreeToPath(WidgetRef ref, String projectId, String path) {
  // Force refresh of files to ensure explorer data is present; the tree view will expand on tap.
  // Here we notify the provider so the UI reflects the newly opened file.
  ref.read(projectFilesProvider(projectId).notifier).fetchFiles();
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FeedbackButton({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: selected ? Colors.blueAccent : Colors.white54),
      ),
    );
  }
}
