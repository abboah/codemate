import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chatbot/chatbot.dart';

final chatHistoryProvider =
    StateNotifierProvider<ChatHistoryNotifier, List<List<ChatMessage>>>(
      (ref) => ChatHistoryNotifier(),
    );

class ChatHistoryNotifier extends StateNotifier<List<List<ChatMessage>>> {
  ChatHistoryNotifier() : super([]);

  void addChat(List<ChatMessage> chat) {
    if (chat.isNotEmpty) {
      // Remove empty or whitespace-only messages
      final filtered = chat.where((m) => m.text.trim().isNotEmpty).toList();
      if (filtered.isNotEmpty) {
        state = [filtered, ...state];
      }
    }
  }

  void removeChatAt(int index) {
    if (index >= 0 && index < state.length) {
      final newState = List<List<ChatMessage>>.from(state);
      newState.removeAt(index);
      state = newState;
    }
  }

  void updateChatAt(int index, List<ChatMessage> updatedChat) {
    if (index >= 0 && index < state.length) {
      final newState = List<List<ChatMessage>>.from(state);
      newState[index] = updatedChat;
      state = newState;
    }
  }

  void clear() {
    state = [];
  }
}
