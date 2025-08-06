import 'package:codemate/models/chat_models.dart';
import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/chat_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class TopicChatModal extends ConsumerStatefulWidget {
  final Topic topic;
  final Enrollment enrollment;
  final List<TopicNote> notes;

  const TopicChatModal({
    super.key,
    required this.topic,
    required this.enrollment,
    required this.notes,
  });

  @override
  ConsumerState<TopicChatModal> createState() => _TopicChatModalState();
}

class _TopicChatModalState extends ConsumerState<TopicChatModal> with SingleTickerProviderStateMixin {
  TopicChat? _selectedChat;
  bool _isPanelVisible = false;
  late AnimationController _animationController;
  late Future<List<TopicChat>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fetchChats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _fetchChats() {
    // Use ref.read to fetch data once and prevent rebuild loops
    _chatsFuture = ref.read(topicChatsProvider({
      'enrollmentId': widget.enrollment.id,
      'topicId': widget.topic.id,
    }).future);
  }

  void _selectChat(TopicChat chat) {
    setState(() {
      _selectedChat = chat;
      _isPanelVisible = false;
      _animationController.reverse();
    });
  }

  void _startNewChat() {
    setState(() {
      _selectedChat = null;
      _isPanelVisible = false;
      _animationController.reverse();
    });
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
      if (_isPanelVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        // Make the modal a bit less wide
        insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 64),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                // Main Chat View
                Row(
                  children: [
                    // This is a spacer to account for the collapsed panel
                    const SizedBox(width: 60),
                    Expanded(
                      child: ChatView(
                        key: ValueKey(_selectedChat?.id ?? 'new'),
                        topic: widget.topic,
                        enrollment: widget.enrollment,
                        notes: widget.notes,
                        chat: _selectedChat,
                        onNewChatStarted: (newChat) {
                          _fetchChats(); // Refetch history
                          _selectChat(newChat);
                        },
                      ),
                    ),
                  ],
                ),
                // Collapsible History Panel
                _buildHistoryPanel(),
                // Top Left Buttons (Menu)
                _buildTopLeftButtons(),
                // Top Right Buttons (New Chat, Close)
                _buildTopRightButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopLeftButtons() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _animationController,
            color: Colors.white,
          ),
          onPressed: _togglePanel,
        ),
      ),
    );
  }

  Widget _buildTopRightButtons() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'New Chat',
              onPressed: _startNewChat,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: _isPanelVisible ? 0 : -280,
      top: 0,
      bottom: 0,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.8), // Increased opacity
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
          boxShadow: [
            if (_isPanelVisible)
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 80.0, bottom: 16.0),
              child: Text(
                'Chat History',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Start New Chat'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _startNewChat,
              ),
            ),
            const Divider(color: Colors.white24, indent: 16, endIndent: 16),
            Expanded(
              child: FutureBuilder<List<TopicChat>>(
                future: _chatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final chats = snapshot.data ?? [];
                  if (chats.isEmpty) {
                    return const Center(
                      child: Text('No chats yet.', style: TextStyle(color: Colors.white54)),
                    );
                  }
                  return ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isSelected = _selectedChat?.id == chat.id;
                      return ListTile(
                        title: Text(
                          chat.title,
                          style: TextStyle(
                            color: isSelected ? Colors.blueAccent : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectChat(chat),
                        selected: isSelected,
                        selectedTileColor: Colors.blueAccent.withOpacity(0.1),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}