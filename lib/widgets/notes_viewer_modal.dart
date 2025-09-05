import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/code_block_builder.dart';
import 'package:codemate/widgets/inline_code_builder.dart';
import 'package:codemate/widgets/pill_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class NotesViewerModal extends StatefulWidget {
  final List<TopicNote> notes;
  const NotesViewerModal({super.key, required this.notes});

  @override
  State<NotesViewerModal> createState() => _NotesViewerModalState();
}

class _NotesViewerModalState extends State<NotesViewerModal> {
  int _selectedNoteIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720), // Reduced from default wide
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0A0D).withOpacity(0.96),
                  const Color(0xFF121216).withOpacity(0.94),
                  const Color(0xFF1A1A20).withOpacity(0.92),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with elegant styling
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF667eea),
                            const Color(0xFF764ba2),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.article_outlined, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Study Notes',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Toggle switch with better spacing
                Center(
                  child: SizedBox(
                    width: 480, // Reduced width for better proportions
                    child: PillToggleSwitch(
                      selectedIndex: _selectedNoteIndex,
                      onToggle: (index) => setState(() => _selectedNoteIndex = index),
                      labels: widget.notes.map((n) => n.title).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Content area with subtle background
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.01),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Markdown(
                      data: widget.notes[_selectedNoteIndex].content,
                      builders: {
                        'pre': CodeBlockBuilder(),
                        'code': InlineCodeBuilder(),
                      },
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9), 
                          fontSize: 15, 
                          height: 1.7,
                          fontWeight: FontWeight.w400,
                        ),
                        h1: GoogleFonts.poppins(
                          color: const Color(0xFF667eea), 
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                        ),
                        h2: GoogleFonts.poppins(
                          color: const Color(0xFF8B7FC7), 
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                        h3: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.95), 
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                        listBullet: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8)),
                        blockquote: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        code: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF92FE9D),
                          backgroundColor: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
