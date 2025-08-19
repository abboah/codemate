import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/quiz_view.dart';
import 'package:codemate/widgets/two_column_layout.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';
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
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TwoColumnLayout(
            pageTitle: 'Quizzes',
            pageDescription:
                'Test your knowledge on "${widget.topic.title}". Take a new quiz or review a previous attempt.',
            buttonText: 'Take New Quiz',
            onButtonPressed: _isCreatingQuiz ? null : _takeNewQuiz,
            isLoading: _isCreatingQuiz,
            rightColumnContent: FutureBuilder<List<QuizAttemptWithQuestions>>(
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
                  return const Center(
                    child: Text(
                      'No quiz attempts yet. Take your first one!',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 20, right: 20),
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attemptWithQuestions = attempts[index];
                    return QuizAttemptCard(
                        attemptWithQuestions: attemptWithQuestions);
                  },
                );
              },
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
    return Card(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Icons.quiz_outlined, color: AppColors.accent),
        title: Text(
          'Quiz Attempt',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        subtitle: Text(
          DateFormat.yMMMd().add_jm().format(attemptWithQuestions.attempt.createdAt),
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
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
      ),
    );
  }
}
