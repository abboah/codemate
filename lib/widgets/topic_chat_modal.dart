import 'package:codemate/models/chat_models.dart';
import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/chat_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

const Color seaBlue = Color(0xFF006994);

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
  String _selectedModel = 'gemini-1.5-flash-latest';

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
        insetPadding: const EdgeInsets.symmetric(horizontal: 180, vertical: 64),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: ChatView(
                        key: ValueKey(_selectedChat?.id ?? 'new'),
                        topic: widget.topic,
                        enrollment: widget.enrollment,
                        notes: widget.notes,
                        chat: _selectedChat,
                        selectedModel: _selectedModel,
                        onNewChatStarted: (newChat) {
                          _fetchChats(); // Refetch history
                          _selectChat(newChat);
                        },
                      ),
                    ),
                  ],
                ),
                _buildHistoryPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _animationController,
                  color: Colors.white70,
                ),
                onPressed: _togglePanel,
              ),
              const SizedBox(width: 8),
              Text(
                widget.topic.title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          _buildModelToggle(),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70),  
                tooltip: 'New Chat',
                onPressed: _startNewChat,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem('gemini-1.5-flash-latest', 'Robin', 'Fast and efficient, great for most tasks.'),
          _buildToggleItem('gemini-2.5-flash-lite', 'Robin Pro', 'More powerful, for complex questions and code generation.'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String model, String name, String tooltip) {
    final isSelected = _selectedModel == model;
    return Tooltip(
      message: tooltip,
      preferBelow: true,
      textStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedModel = model;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? seaBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: _isPanelVisible ? 0 : -320,
      top: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                _buildPanelHeader(),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: FutureBuilder<List<TopicChat>>(
                    future: _chatsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: seaBlue));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.white70)));
                      }
                      final chats = snapshot.data ?? [];
                      if (chats.isEmpty) {
                        return Center(
                          child: Text('No chats yet.', style: GoogleFonts.poppins(color: Colors.white54)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final isSelected = _selectedChat?.id == chat.id;
                          return Card(
                            color: isSelected ? seaBlue.withOpacity(0.3) : Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: ListTile(
                              title: Text(
                                chat.title,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectChat(chat),
                              selected: isSelected,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chat History',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _togglePanel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text('Start New Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: seaBlue,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startNewChat,
          ),
        ],
      ),
    );
  }
}