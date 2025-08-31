import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/quiz_view.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class QuizLobbyPage extends ConsumerStatefulWidget {
  final Topic topic;
  final Enrollment enrollment;

  const QuizLobbyPage({
    super.key,
    required this.topic,
    required this.enrollment,
  });

  @override
  ConsumerState<QuizLobbyPage> createState() => _QuizLobbyPageState();
}

class _QuizLobbyPageState extends ConsumerState<QuizLobbyPage> {
  bool _isCreatingQuiz = false;
  late Future<List<QuizAttemptWithQuestions>> _attemptsFuture;

  @override
  void initState() {
    super.initState();
    _fetchAttempts();
  }

  void _fetchAttempts() {
    // Use ref.read to fetch the data once and avoid rebuild loops.
    _attemptsFuture = ref.read(quizAttemptsWithQuestionsProvider({
      'enrollmentId': widget.enrollment.id,
      'topicId': widget.topic.id,
    }).future);
  }

  void _takeNewQuiz() async {
    setState(() => _isCreatingQuiz = true);
    try {
      final questions = await ref.read(createQuizProvider({
        'topic': widget.topic,
        'enrollment': widget.enrollment,
      }).future);

      if (mounted) {
        // Pop the lobby and then show the quiz. When the lobby is reopened,
        // initState will call _fetchAttempts again to get the new list.
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => QuizView(questions: questions),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to create quiz: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingQuiz = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            padding: const EdgeInsets.all(28),
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
            child: Stack(
              children: <Widget>[
                // Close button (top-right)
                Positioned(
                  right: 8,
                  top: 8,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    // Left Half - Description and Button
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF7F00FF).withOpacity(0.3),
                                        const Color(0xFFE100FF).withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.quiz_outlined,
                                    color: Color(0xFFE100FF),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Quizzes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Test your knowledge on "${widget.topic.title}". Take a new quiz or review a previous attempt.',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF00C851).withOpacity(0.3),
                                              const Color(0xFF007E33).withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Color(0xFF00C851),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Ready to test yourself?',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Challenge yourself with a personalized quiz and track your progress.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isCreatingQuiz ? null : _takeNewQuiz,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00C851),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ).copyWith(
                                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                                          if (states.contains(MaterialState.disabled)) {
                                            return Colors.grey.withOpacity(0.3);
                                          }
                                          if (states.contains(MaterialState.hovered)) {
                                            return const Color(0xFF00E676);
                                          }
                                          return const Color(0xFF00C851);
                                        }),
                                      ),
                                      child: _isCreatingQuiz
                                          ? Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Creating Quiz...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.quiz, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Take New Quiz',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Half - Quiz History
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: FutureBuilder<List<QuizAttemptWithQuestions>>(
                          future: _attemptsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 240,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BigShimmer(width: 220, height: 14),
                                      SizedBox(height: 12),
                                      BigShimmer(width: 200, height: 14),
                                      SizedBox(height: 12),
                                      BigShimmer(width: 180, height: 14),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }
                            final attempts = snapshot.data ?? [];
                            if (attempts.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF7F00FF).withOpacity(0.3),
                                            const Color(0xFFE100FF).withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.quiz_outlined,
                                        color: Colors.white70,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No quiz attempts yet',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Take your first quiz to get started!',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF00A8FF).withOpacity(0.3),
                                              const Color(0xFF0078FF).withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.history,
                                          color: Color(0xFF00A8FF),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Quiz History',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                    itemCount: attempts.length,
                                    itemBuilder: (context, index) {
                                      final attemptWithQuestions = attempts[index];
                                      return QuizAttemptCard(
                                          attemptWithQuestions: attemptWithQuestions);
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuizAttemptCard extends ConsumerWidget {
  final QuizAttemptWithQuestions attemptWithQuestions;

  const QuizAttemptCard({super.key, required this.attemptWithQuestions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (context.mounted) {
              Navigator.of(context).pop(); // Close the lobby
              showDialog(
                context: context,
                builder: (context) => QuizView(
                    questions: attemptWithQuestions.questions.map((q) => q.toMap()).toList()),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7F00FF).withOpacity(0.3),
                        const Color(0xFFE100FF).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.quiz_outlined,
                    color: Color(0xFFE100FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Attempt',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(attemptWithQuestions.attempt.createdAt),
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
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
