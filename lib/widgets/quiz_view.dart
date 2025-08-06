import 'dart:async';
import 'package:codemate/widgets/quiz_summary_modal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class QuizView extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  const QuizView({super.key, required this.questions});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedOption;
  bool _answered = false;

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
    } else {
      // Quiz is done
      Navigator.of(context).pop(); // Close the quiz view modal
      showDialog(
        context: context,
        builder: (context) => QuizSummaryModal(
          score: _score,
          total: widget.questions.length,
        ),
      );
    }
  }

  void _handleAnswer(String optionKey) {
    if (_answered) return;

    setState(() {
      _selectedOption = optionKey;
      _answered = true;
      if (optionKey == widget.questions[_currentIndex]['correct_option']) {
        _score++;
      }
    });

    Timer(const Duration(seconds: 2), _nextQuestion);
  }

  Color _getOptionColor(String optionKey) {
    if (!_answered) return Colors.white.withOpacity(0.1);
    final correctOption = widget.questions[_currentIndex]['correct_option'];
    if (optionKey == correctOption) return Colors.green.withOpacity(0.5);
    if (optionKey == _selectedOption && optionKey != correctOption) {
      return Colors.red.withOpacity(0.5);
    }
    return Colors.white.withOpacity(0.1);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final options = question['options'] as Map<String, dynamic>;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_currentIndex + 1}/${widget.questions.length}',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(right: 40.0), // Space for the close button
                    child: Text(
                      question['question_text'],
                      style: GoogleFonts.poppins(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ...options.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => _handleAnswer(entry.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getOptionColor(entry.key),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${entry.key}.',
                                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const Spacer(),
                  if (_answered)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explanation:',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            question['explanation'],
                            style: GoogleFonts.poppins(color: Colors.white70, height: 1.5),
                          ),
                        ],
                      ),
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
    );
  }
}
