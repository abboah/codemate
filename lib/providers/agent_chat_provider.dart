import 'dart:async';
import 'package:codemate/models/project.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codemate/providers/active_chat_provider.dart';
import 'package:codemate/providers/chat_history_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentChatMessage {
  final String id;
  String content;
  final bool isUser;
  final DateTime createdAt;

  AgentChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.createdAt,
  });

  factory AgentChatMessage.fromMap(Map<String, dynamic> map) {
    return AgentChatMessage(
      id: map['id'],
      content: map['content'],
      isUser: map['sender'] == 'user',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Content toContent() {
    return Content(isUser ? 'user' : 'model', [TextPart(content)]);
  }
}

final agentChatProvider =
    ChangeNotifierProvider.family<AgentChatProvider, (String?, Project?)>(
  (ref, ids) {
    final provider = AgentChatProvider(ref: ref, chatId: ids.$1, project: ids.$2);
    provider.fetchMessages();
    return provider;
  },
);

class AgentChatProvider extends ChangeNotifier {
  final Ref ref;
  final String? chatId;
  final Project? project;
  final SupabaseClient _client = Supabase.instance.client;
  final ChatService _chatService = ChatService();

  StreamSubscription<String>? _streamSubscription;

  AgentChatProvider({required this.ref, required this.chatId, required this.project});

  List<AgentChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;

  List<AgentChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    if (chatId == null) {
      _messages = [];
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('chat_id', chatId!)
          .order('created_at', ascending: true);

      _messages = (response as List)
          .map((item) => AgentChatMessage.fromMap(item))
          .toList();
    } catch (e) {
      _error = "Failed to fetch messages: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (project == null || chatId == null) return;

    final userMessage = AgentChatMessage(
      id: DateTime.now().toIso8601String(), // Temp ID
      content: text,
      isUser: true,
      createdAt: DateTime.now(),
    );
    _messages.add(userMessage);
    _isGenerating = true;
    notifyListeners();

    // Save user message immediately
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender': 'user',
      'content': text,
    });

    _startStreamingResponse(userMessage);
  }

  void _startStreamingResponse(AgentChatMessage userMessage) {
    final history = _messages.map((m) => m.toContent()).toList();

    final systemPrompt = """
      You are Robin, an expert AI pair programmer.
      You are currently working on a project with the following details:
      - Project Name: ${project!.name}
      - Description: ${project!.description}
      
      Your task is to assist the user with their requests, providing code, explanations, and solutions related to this project.
      """;

    final aiMessage = AgentChatMessage(
      id: DateTime.now().toIso8601String(), // Temp ID
      content: '',
      isUser: false,
      createdAt: DateTime.now(),
    );
    _messages.add(aiMessage);
    notifyListeners();

    _streamSubscription = _chatService
        .sendMessage(userMessage.content, history, systemPrompt)
        .listen((chunk) {
      aiMessage.content += chunk;
      notifyListeners();
    }, onDone: () async {
      _isGenerating = false;
      
      // Save the AI message
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender': 'agent',
        'content': aiMessage.content,
      });

      // Check if this was the first exchange to generate title
      if (_messages.length == 2) {
        final title = await _chatService.generateChatTitle(
            userMessage.content, aiMessage.content);
        await _client
            .from('agent_chats')
            .update({'name': title}).eq('id', chatId!);
        // Invalidate history to show the new title
        ref.invalidate(chatHistoryProvider(project!.id));
      }

      notifyListeners();
    }, onError: (e) {
      _error = "Failed to get response: $e";
      aiMessage.content = "Error: $_error";
      _isGenerating = false;
      _messages.remove(userMessage); // Remove the user message if AI fails
      notifyListeners();
    });
  }
}
