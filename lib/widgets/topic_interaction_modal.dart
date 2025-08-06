import 'dart:async';
import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/quiz_lobby_page.dart';
import 'package:codemate/widgets/animated_loading_indicator.dart';
import 'package:codemate/widgets/code_block_builder.dart';
import 'package:codemate/widgets/inline_code_builder.dart';
import 'package:codemate/widgets/notes_viewer_modal.dart';
import 'package:codemate/widgets/quiz_view.dart';
import 'package:codemate/widgets/topic_chat_modal.dart';
import 'package:codemate/widgets/fun_fact_modal.dart';
import 'package:codemate/widgets/practice_problem_modal.dart';
import 'package:codemate/widgets/suggested_projects_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

enum NotesScreenState { fetching, generating, loaded, error }


class TopicInteractionModal extends ConsumerStatefulWidget {
  final Topic topic;
  final Enrollment? enrollment;

  const TopicInteractionModal({
    super.key,
    required this.topic,
    this.enrollment,
  });

  @override
  ConsumerState<TopicInteractionModal> createState() => _TopicInteractionModalState();
}

class _TopicInteractionModalState extends ConsumerState<TopicInteractionModal> {
  NotesScreenState _screenState = NotesScreenState.fetching;
  List<TopicNote> _notes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Only fetch notes if the user is enrolled in the course.
    if (widget.enrollment != null) {
      _fetchOrGenerateNotes();
    } else {
      // If not enrolled, there are no notes to load.
      _screenState = NotesScreenState.loaded;
    }
  }

  Future<void> _fetchOrGenerateNotes() async {
    print('[ModalLifecycle] Starting _fetchOrGenerateNotes...');
    if (!mounted) return;

    setState(() {
      _screenState = NotesScreenState.fetching;
    });

    // This should only be called when enrollment is not null, so we can safely use !.
    if (widget.enrollment == null) return;

    try {
      final existingNotes = await ref.read(topicNotesProvider({
        'enrollmentId': widget.enrollment!.id,
        'topicId': widget.topic.id,
      }).future);

      if (existingNotes.isNotEmpty) {
        print('[ModalLifecycle] Notes found in database.');
        if (mounted) {
          setState(() {
            _notes = existingNotes;
            _screenState = NotesScreenState.loaded;
          });
        }
      } else {
        print('[ModalLifecycle] No notes found. Triggering generation...');
        if (mounted) setState(() => _screenState = NotesScreenState.generating);
        
        final newNotes = await ref.read(createNotesProvider({
          'topic': widget.topic,
          'enrollment': widget.enrollment!,
        }).future);

        print('[ModalLifecycle] Note generation complete.');
        if (mounted) {
          setState(() {
            _notes = newNotes;
            _screenState = NotesScreenState.loaded;
          });
        }
      }
    } catch (e) {
      print('[ModalLifecycle] Error: $e');
      if (mounted) {
        setState(() {
          _screenState = NotesScreenState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[TopicInteractionModal] Build triggered. Screen state: $_screenState');
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.topic.title,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildActionGrid(),
                    const SizedBox(height: 32),
                    Expanded(
                      child: _buildNotesSection(),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    // Notes and other actions are only available if the user is enrolled.
    final isEnrolled = widget.enrollment != null;
    final notesExist = isEnrolled && _screenState == NotesScreenState.loaded;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildActionButton(
          icon: Icons.notes_outlined,
          label: 'View Notes',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => NotesViewerModal(notes: _notes),
            );
          },
          isBlurred: !notesExist,
        ),
        _buildActionButton(
          icon: Icons.quiz_outlined,
          label: 'Take a Quiz',
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => QuizLobbyPage(
                topic: widget.topic,
                enrollment: widget.enrollment!,
              ),
            );
          },
          isBlurred: !isEnrolled || !notesExist,
        ),
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          label: 'Ask Robin',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => TopicChatModal(
                topic: widget.topic,
                enrollment: widget.enrollment!,
                notes: _notes,
              ),
            );
          },
          isBlurred: !isEnrolled || !notesExist,
        ),
        _buildActionButton(
          icon: Icons.lightbulb_outline,
          label: 'Fun Fact',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => FunFactModal(topic: widget.topic),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.construction_outlined,
          label: 'Projects',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => SuggestedProjectsModal(topic: widget.topic),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.fitness_center_outlined,
          label: 'Practice',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => PracticeProblemModal(topic: widget.topic),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    switch (_screenState) {
      case NotesScreenState.fetching:
        return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Fetching notes...')]));
      case NotesScreenState.generating:
        return const AnimatedLoadingIndicator();
      case NotesScreenState.error:
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchOrGenerateNotes, child: const Text('Retry'))]));
      case NotesScreenState.loaded:
        return _buildNotesPreview(_notes);
    }
  }

  Widget _buildNotesPreview(List<TopicNote> notes) {
    if (notes.isEmpty) {
      return const Center(child: Text('Something went wrong. No notes found.'));
    }
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => NotesViewerModal(notes: notes),
        );
      },
      child: Container(
        key: const ValueKey('preview'),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  notes.first.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Icon(Icons.open_in_full, color: Colors.white70),
              ],
            ),
            const Divider(color: Colors.white24, height: 24),
            Expanded(
              child: Markdown(
                data: notes.first.content,
                builders: {
                  'pre': CodeBlockBuilder(),
                  'code': InlineCodeBuilder(),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: GoogleFonts.poppins(color: Colors.white70, fontSize: 14, height: 1.5),
                  h1: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  h2: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  h3: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                  listBullet: GoogleFonts.poppins(color: Colors.white70),
                  blockquote: GoogleFonts.poppins(color: Colors.white70),
                ),
                shrinkWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isBlurred = false,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isBlurred || isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isBlurred ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
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