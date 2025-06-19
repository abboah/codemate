import 'package:flutter/material.dart';

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    const step = 40.0;

    // Draw grid lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw subtle center gradient
    final center = Offset(size.width / 2, size.height / 2);
    final gradient = RadialGradient(colors: [Colors.black, Color(0xFF0A0A0F)]);
    canvas.drawCircle(
      center,
      size.width * 0.6,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.6),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
