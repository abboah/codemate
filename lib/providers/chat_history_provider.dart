import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentChatSession {
  final String id;
  final String projectId;
  final String? name;
  final DateTime createdAt;

  AgentChatSession({
    required this.id,
    required this.projectId,
    this.name,
    required this.createdAt,
  });

  factory AgentChatSession.fromMap(Map<String, dynamic> map) {
    return AgentChatSession(
      id: map['id'],
      projectId: map['project_id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

final chatHistoryProvider =
    AsyncNotifierProvider.family<ChatHistoryNotifier, List<AgentChatSession>, String>(
  () => ChatHistoryNotifier(),
);

class ChatHistoryNotifier extends FamilyAsyncNotifier<List<AgentChatSession>, String> {
  final _client = Supabase.instance.client;

  @override
  Future<List<AgentChatSession>> build(String arg) async {
    final projectId = arg;
    try {
      final response = await _client
          .from('agent_chats')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => AgentChatSession.fromMap(item))
          .toList();
    } catch (e) {
      print('Error fetching chat history: $e');
      throw Exception('Failed to load chat history');
    }
  }

  Future<String> createChat(String projectId) async {
    try {
      final newChatResponse = await _client.from('agent_chats').insert({
        'project_id': projectId,
        'user_id': _client.auth.currentUser!.id,
        'name': 'New Chat...', // Placeholder title
      }).select('id');
      
      final newChatId = newChatResponse[0]['id'];
      
      // Refresh the list of chats
      ref.invalidateSelf();
      await future; // Wait for the list to rebuild

      return newChatId;
    } catch (e) {
      print('Error creating new chat: $e');
      throw Exception('Failed to create new chat');
    }
  }
}
