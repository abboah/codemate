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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7F00FF).withOpacity(0.2),
                            const Color(0xFFE100FF).withOpacity(0.2),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFE100FF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Question ${_currentIndex + 1}/${widget.questions.length}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFE100FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(right: 40.0), // Space for the close button
                      child: Text(
                        question['question_text'],
                        style: GoogleFonts.poppins(
                          fontSize: 22, 
                          color: Colors.white, 
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...options.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () => _handleAnswer(entry.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: _getOptionColor(entry.key),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getOptionBorderColor(entry.key),
                                width: 1.5,
                              ),
                              boxShadow: [
                                if (_answered && entry.key == widget.questions[_currentIndex]['correct_option'])
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                if (_answered && entry.key == _selectedOption && entry.key != widget.questions[_currentIndex]['correct_option'])
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      entry.key.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14, 
                                        color: Colors.white, 
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16, 
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00A8FF).withOpacity(0.1),
                              const Color(0xFF0078FF).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0078FF).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
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
                                    Icons.lightbulb_outline,
                                    color: Color(0xFF00A8FF),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Explanation',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600, 
                                    color: const Color(0xFF00A8FF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              question['explanation'],
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9), 
                                height: 1.5,
                                fontSize: 14,
                              ),
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
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOptionBorderColor(String optionKey) {
    if (!_answered) return Colors.white.withOpacity(0.15);
    final correctOption = widget.questions[_currentIndex]['correct_option'];
    if (optionKey == correctOption) return Colors.green.withOpacity(0.6);
    if (optionKey == _selectedOption && optionKey != correctOption) {
      return Colors.red.withOpacity(0.6);
    }
    return Colors.white.withOpacity(0.15);
  }
}
