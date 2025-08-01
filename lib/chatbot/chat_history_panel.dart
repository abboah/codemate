import 'package:codemate/providers/active_chat_provider.dart';
import 'package:codemate/providers/chat_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatHistoryPanel extends ConsumerWidget {
  final String projectId;
  const ChatHistoryPanel({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatHistoryState = ref.watch(chatHistoryProvider(projectId));
    final activeChatId = ref.watch(activeChatProvider);

    return Container(
      width: 280,
      color: Colors.black.withOpacity(0.15),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat Sessions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          Expanded(
            child: chatHistoryState.when(
              data: (chats) {
                if (activeChatId == null && chats.isNotEmpty) {
                  Future.microtask(() =>
                      ref.read(activeChatProvider.notifier).state = chats.first.id);
                }

                if (chats.isEmpty) {
                  return const Center(
                    child: Text(
                      'No chat sessions yet.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final isActive = chat.id == activeChatId;
                    return ListTile(
                      dense: true,
                      selected: isActive,
                      selectedTileColor: Colors.blueAccent.withOpacity(0.2),
                      leading: const Icon(Icons.chat_bubble_outline,
                          size: 16, color: Colors.white70),
                      title: Text(
                        chat.name ?? 'New Chat',
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        ref.read(activeChatProvider.notifier).state = chat.id;
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
