import 'dart:ui';

import 'package:flutter/material.dart';

class ChatHistorySidebar extends StatefulWidget {
  final List<String> chatTitles;

  const ChatHistorySidebar({super.key, required this.chatTitles});

  @override
  State<ChatHistorySidebar> createState() => _ChatHistorySidebarState();
}

class _ChatHistorySidebarState extends State<ChatHistorySidebar>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  void _toggleSidebar() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = 300;

    return Stack(
      children: [
        // Toggle Button
        Positioned(
          top: 50,
          right: 20,
          // child: FloatingActionButton(
          //   mini: true,
          //   backgroundColor: Colors.black.withOpacity(0.5),
          //   child: Icon(
          //     _isOpen ? Icons.close : Icons.history,
          //     color: Colors.white,
          //   ),
          //   onPressed: _toggleSidebar,
          // ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.blue.withOpacity(0.5),
                  child: Icon(
                    _isOpen ? Icons.close : Icons.history,
                    color: Colors.white,
                  ),
                  onPressed: _toggleSidebar,
                ),
              ),
            ),
          ),
        ),

        // Overlay (closes when clicked outside)
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleSidebar,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

        // Animated Sidebar
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          right: _isOpen ? 0 : -sidebarWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              20,
              // topLeft: Radius.circular(20),
              // bottomLeft: Radius.circular(20),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: sidebarWidth,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.chatTitles.length,
                        separatorBuilder:
                            (_, __) => const Divider(color: Colors.white24),
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white70,
                            ),
                            title: Text(
                              widget.chatTitles[index],
                              style: const TextStyle(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              // Load that chat...
                              debugPrint(
                                'Load chat: ${widget.chatTitles[index]}',
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // New Chat button inside the sidebar
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          'New Chat',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.5),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Start new chat functionality
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
