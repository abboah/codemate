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
  }) async {
    _isSending = true;
    notifyListeners();

    final userMessage = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.user,
      messageType: AgentMessageType.text,
      content: text,
      sentAt: DateTime.now(),
    );
    
    final aiPlaceholder = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.ai,
      messageType: AgentMessageType.text,
      content: '...',
      sentAt: DateTime.now(),
    );

    _messages.add(userMessage);
    _messages.add(aiPlaceholder);
    notifyListeners();

    String fullResponse = '';

    try {
      final history = _messages.where((m) => m.id != userMessage.id && m.id != aiPlaceholder.id).map((m) {
        final role = m.sender == MessageSender.user ? 'user' : 'model';
        return gen_ai.Content(role, [gen_ai.TextPart(m.content)]);
      }).toList();

      const systemInstruction =
          'You are Robin, an expert AI software development assistant...';

      final stream = _chatService.sendMessage(text, history, systemInstruction, model: model);

      await for (var chunk in stream) {
        fullResponse += chunk;
        final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
        if(index != -1) {
          _messages[index] = _messages[index].copyWith(content: fullResponse);
          notifyListeners();
        }
      }

      // Save both messages after streaming is complete
      await _client.from('agent_chat_messages').insert(
        {
          'id': userMessage.id,
          'chat_id': userMessage.chatId,
          'sender': 'user',
          'message_type': 'text',
          'content': userMessage.content,
          'sent_at': userMessage.sentAt.toIso8601String(),
        }
      );
      await _client.from('agent_chat_messages').insert(
        {
          'id': aiPlaceholder.id,
          'chat_id': chatId,
          'sender': 'ai',
          'message_type': 'text',
          'content': fullResponse,
          'sent_at': aiPlaceholder.sentAt.toIso8601String(),
        }
      );

      _handleToolCall(fullResponse);

    } catch (e) {
       final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if(index != -1) {
        _messages[index] = _messages[index].copyWith(content: "Sorry, an error occurred: $e");
      }
      _error = "Failed to send message: $e";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _handleToolCall(String response) async {
    try {
      final decodedResponse = jsonDecode(response);
      if (decodedResponse is Map<String, dynamic> && decodedResponse.containsKey('tool_code')) {
        final toolCode = decodedResponse['tool_code'];
        final args = decodedResponse['args'] as Map<String, dynamic>;
        final projectId = _ref.read(projectFilesProvider(chatId).notifier).projectId;
        final filesNotifier = _ref.read(projectFilesProvider(projectId).notifier);

        final toolMessage = AgentChatMessage(
          id: _uuid.v4(),
          chatId: chatId,
          sender: MessageSender.ai,
          messageType: AgentMessageType.toolInProgress,
          content: 'Executing tool: $toolCode...',
          sentAt: DateTime.now(),
        );
        _messages.add(toolMessage);
        notifyListeners();

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
          final index = _messages.indexWhere((m) => m.id == toolMessage.id);
          if (index != -1) {
            _messages[index] = toolMessage.copyWith(
              messageType: AgentMessageType.toolResult,
              content: 'Tool executed successfully.',
            );
          }
        } catch (e) {
          final index = _messages.indexWhere((m) => m.id == toolMessage.id);
          if (index != -1) {
            _messages[index] = toolMessage.copyWith(
              messageType: AgentMessageType.error,
              content: 'Error executing tool: $e',
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      // Not a tool call, ignore
    }
  }
}
