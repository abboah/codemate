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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // This Spacer pushes the IconButton to the right
                  const Spacer(), 
                  Center(
                    child: SizedBox(
                      width: 600, // Slightly wider
                      child: PillToggleSwitch(
                        selectedIndex: _selectedNoteIndex,
                        onToggle: (index) => setState(() => _selectedNoteIndex = index),
                        labels: widget.notes.map((n) => n.title).toList(),
                      ),
                    ),
                  ),
                  // This Spacer ensures the SizedBox remains centered
                  const Spacer(), 
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Markdown(
                  data: widget.notes[_selectedNoteIndex].content,
                  builders: {
                    'pre': CodeBlockBuilder(),
                    'code': InlineCodeBuilder(),
                  },
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                    h1: TextStyle(color: Colors.blueAccent[100], fontWeight: FontWeight.bold),
                    h2: TextStyle(color: Colors.blueAccent[100], fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
