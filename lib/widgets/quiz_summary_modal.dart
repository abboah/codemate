import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class QuizSummaryModal extends StatefulWidget {
  final int score;
  final int total;

  const QuizSummaryModal({
    super.key,
    required this.score,
    required this.total,
  });

  @override
  State<QuizSummaryModal> createState() => _QuizSummaryModalState();
}

class _QuizSummaryModalState extends State<QuizSummaryModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.score / widget.total)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.total * 100).round();
    final isExcellent = percentage >= 80;
    final isGood = percentage >= 60;
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Container(
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
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isExcellent 
                        ? [const Color(0xFF00C851).withOpacity(0.3), const Color(0xFF007E33).withOpacity(0.3)]
                        : isGood
                          ? [const Color(0xFFFF6B35).withOpacity(0.3), const Color(0xFFD84315).withOpacity(0.3)]
                          : [const Color(0xFFFF1744).withOpacity(0.3), const Color(0xFFD50000).withOpacity(0.3)],
                    ),
                  ),
                  child: Icon(
                    isExcellent 
                      ? Icons.emoji_events 
                      : isGood 
                        ? Icons.thumb_up_alt 
                        : Icons.refresh,
                    color: isExcellent 
                      ? const Color(0xFF00C851)
                      : isGood
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFFFF1744),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isExcellent 
                    ? 'Excellent!' 
                    : isGood 
                      ? 'Well Done!' 
                      : 'Keep Trying!',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiz Complete',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 180,
                  height: 180,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ScorePainter(
                          progress: _animation.value,
                          score: widget.score,
                          total: widget.total,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Score',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.score} out of ${widget.total} ($percentage%)',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7F00FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.hovered)) {
                          return const Color(0xFF9933FF);
                        }
                        return const Color(0xFF7F00FF);
                      }),
                    ),
                    child: Text(
                      'Continue Learning',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

class ScorePainter extends CustomPainter {
  final double progress;
  final int score;
  final int total;

  ScorePainter({required this.progress, required this.score, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;
    const strokeWidth = 14.0;
    final percentage = (score / total * 100).round();

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc with gradient based on score
    final List<Color> gradientColors;
    if (percentage >= 80) {
      gradientColors = [const Color(0xFF00C851), const Color(0xFF007E33)];
    } else if (percentage >= 60) {
      gradientColors = [const Color(0xFFFF6B35), const Color(0xFFD84315)];
    } else {
      gradientColors = [const Color(0xFFFF1744), const Color(0xFFD50000)];
    }

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: gradientColors,
        startAngle: -90 * (3.14159 / 180),
        endAngle: (270 * progress - 90) * (3.14159 / 180),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * (3.14159 / 180),
      360 * progress * (3.14159 / 180),
      false,
      progressPaint,
    );

    // Score text
    final scoreTextSpan = TextSpan(
      text: '$score',
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
    final scoreTextPainter = TextPainter(
      text: scoreTextSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    scoreTextPainter.layout();

    // Total text
    final totalTextSpan = TextSpan(
      text: '/$total',
      style: GoogleFonts.poppins(
        color: Colors.white.withOpacity(0.7),
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
    final totalTextPainter = TextPainter(
      text: totalTextSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    totalTextPainter.layout();

    // Percentage text
    final percentageTextSpan = TextSpan(
      text: '$percentage%',
      style: GoogleFonts.poppins(
        color: gradientColors[0],
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final percentageTextPainter = TextPainter(
      text: percentageTextSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    percentageTextPainter.layout();

    // Position texts
    final totalWidth = scoreTextPainter.width + totalTextPainter.width;
    final scoreX = center.dx - totalWidth / 2;
    final totalX = scoreX + scoreTextPainter.width;
    final textY = center.dy - scoreTextPainter.height / 2;

    scoreTextPainter.paint(canvas, Offset(scoreX, textY));
    totalTextPainter.paint(canvas, Offset(totalX, textY));
    
    // Percentage below
    percentageTextPainter.paint(
      canvas,
      Offset(center.dx - percentageTextPainter.width / 2, center.dy + 20),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
