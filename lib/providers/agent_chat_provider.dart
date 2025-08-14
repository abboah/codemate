import 'dart:async';
import 'dart:convert';
import 'package:codemate/models/agent_chat_message.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:uuid/uuid.dart';

final chatServiceProvider = Provider((ref) => ChatService());

final projectChatsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final response = await Supabase.instance.client
      .from('agent_chats')
      .select('id, title, created_at')
      .eq('project_id', projectId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final agentChatProvider =
    ChangeNotifierProvider.family<AgentChatNotifier, String>((ref, chatId) {
  return AgentChatNotifier(chatId, ref.read(chatServiceProvider), ref);
});

class AgentChatNotifier extends ChangeNotifier {
  final String chatId;
  final ChatService _chatService;
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final Ref _ref;

  AgentChatNotifier(this.chatId, this._chatService, this._ref) {
    if (chatId.isNotEmpty) {
      fetchMessages();
    }
  }

  List<AgentChatMessage> _messages = [];
  List<AgentChatMessage> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _error;
  String? get error => _error;

  Future<void> fetchMessages() async {
    if (chatId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _client
          .from('agent_chat_messages')
          .select()
          .eq('chat_id', chatId)
          .order('sent_at', ascending: true);

      _messages = response.map((data) => AgentChatMessage.fromMap(data)).toList();
      _error = null;
    } catch (e) {
      _error = "Failed to fetch messages: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String text,
    required String model,
    required String projectId,
    List<Map<String, dynamic>> attachedFiles = const [],
    bool useAskHandler = false,
  }) async {
    _isSending = true;
    notifyListeners();

    if (chatId.isEmpty) return;

    final userMessage = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.user,
      messageType: AgentMessageType.text,
      content: text,
      attachedFiles: attachedFiles,
      sentAt: DateTime.now(),
    );

    final aiPlaceholder = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.ai,
      messageType: AgentMessageType.toolInProgress,
      content: 'Robin is thinking...',
      sentAt: DateTime.now(),
    );

    _messages.add(userMessage);
    _messages.add(aiPlaceholder);
    notifyListeners();

    try {
      // 1. Prepare history for the backend function
      final historyForBackend = _messages
          .where((m) => m.id != userMessage.id && m.id != aiPlaceholder.id && m.messageType == AgentMessageType.text)
          .map((m) => {
                "role": m.sender == MessageSender.user ? "user" : "model",
                "parts": [{"text": m.content}]
              })
          .toList();

      final functionName = useAskHandler ? 'agent-chat-handler' : 'agent-handler';

      // 2. Invoke the Supabase Edge Function
      final response = await _client.functions.invoke(
        functionName,
        body: {
          'prompt': text,
          'history': historyForBackend,
          'projectId': projectId,
          'model': model,
          'attachedFiles': attachedFiles,
        },
      );

      if (response.status != 200) {
        throw Exception('Backend function failed: ${response.data}');
      }

      final Map<String, dynamic> result = response.data as Map<String, dynamic>;
      final aiResponseContent = result['text'] as String? ?? '';
      final List<dynamic> fileEdits = (result['fileEdits'] as List?) ?? [];

      // 3. Prepare the AI message for streaming and show tool results immediately
      final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if (index != -1) {
        _messages[index] = aiPlaceholder.copyWith(
          content: '',
          messageType: AgentMessageType.text,
          toolResults: { 'fileEdits': fileEdits },
        );
        notifyListeners();

        // 4. Illusion streaming: gradually append text to placeholder
        const chunkSize = 24;
        for (int i = 0; i < aiResponseContent.length; i += chunkSize) {
          final end = (i + chunkSize < aiResponseContent.length) ? i + chunkSize : aiResponseContent.length;
          final current = _messages[index].content + aiResponseContent.substring(i, end);
          _messages[index] = _messages[index].copyWith(
            content: current,
          );
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 12));
        }
      }

      // 5. Persist messages to the database once complete
      await _client.from('agent_chat_messages').insert(userMessage.toMap());
      final aiWithToolResults = _messages[index];
      await _client.from('agent_chat_messages').insert(aiWithToolResults.toMap());

      // 6. Refresh the file tree in case the agent modified files
      _ref.read(projectFilesProvider(projectId).notifier).fetchFiles();

    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if(index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: "Sorry, an error occurred: $e",
          messageType: AgentMessageType.error,
        );
      }
      _error = "Failed to send message: $e";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
