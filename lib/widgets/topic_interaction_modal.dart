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
import 'package:codemate/themes/colors.dart';

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
          constraints: const BoxConstraints(maxWidth: 880),
          child: Stack(
            children: [
              // Dark glassy container with elegant styling
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0A0A0D).withOpacity(0.95),
                      const Color(0xFF121216).withOpacity(0.92),
                      const Color(0xFF1A1A20).withOpacity(0.90),
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
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
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.topic.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Interactive Learning Session',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _buildActionGrid(),
                    const SizedBox(height: 28),
                    Expanded(child: _buildNotesSection()),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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
          gradientColors: const [Color(0xFF667eea), Color(0xFF764ba2)],
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
          gradientColors: const [Color(0xFF7F00FF), Color(0xFFE100FF)],
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
          gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
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
          gradientColors: const [Color(0xFFFC466B), Color(0xFF3F5EFB)],
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
          gradientColors: const [Color(0xFFFFAF7B), Color(0xFFD76D77), Color(0xFF3A1C71)],
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
          gradientColors: const [Color(0xFF11998e), Color(0xFF38ef7d)],
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
    required List<Color> gradientColors,
  }) {
    // Colorful, unique professional action tiles
    return _ActionTile(
      icon: icon,
      label: label,
      onTap: isBlurred || isLoading ? null : onTap,
      disabled: isBlurred,
      loading: isLoading,
      gradientColors: gradientColors,
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool loading;
  final List<Color> gradientColors;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.disabled = false,
    this.loading = false,
    required this.gradientColors,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tileColor = widget.disabled
        ? Colors.white.withOpacity(0.02)
        : Colors.white.withOpacity(0.06);
    final borderColor = widget.disabled
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.12);
    final iconGradient = widget.disabled 
        ? widget.gradientColors.map((c) => c.withOpacity(0.3)).toList()
        : widget.gradientColors;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: _hovered && widget.onTap != null ? 1.04 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tileColor,
                Colors.white.withOpacity(0.02),
              ],
            ),
            boxShadow: _hovered && widget.onTap != null
                ? [
                    BoxShadow(
                      color: iconGradient.first.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        height: 22, 
                        width: 22, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconGradient.first),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: iconGradient,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: iconGradient.first.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(widget.icon, color: Colors.white, size: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.label,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(widget.disabled ? 0.5 : 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}