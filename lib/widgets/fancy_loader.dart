import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:codemate/themes/colors.dart';

/// A sleek wave/shimmer hybrid loader used across the IDE UI.
/// - size controls the overall width; height scales proportionally.
/// - color controls the primary accent (defaults to blueAccent).
class WaveLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const WaveLoader({super.key, this.size = 24, this.color, this.strokeWidth = 2});

  @override
  State<WaveLoader> createState() => _WaveLoaderState();
}

class _WaveLoaderState extends State<WaveLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final color = widget.color ?? AppColors.darkerAccent;
    final height = widget.size * 0.6;
    return SizedBox(
      width: widget.size,
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _WavePainter(progress: _controller.value, color: color, strokeWidth: widget.strokeWidth),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final double strokeWidth;

  _WavePainter({required this.progress, required this.color, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Create a subtle gradient shimmer across the wave
    final gradient = LinearGradient(
      colors: [
        color.withOpacity(0.15),
        color.withOpacity(0.9),
        color.withOpacity(0.15),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(-1, 0),
      end: Alignment(1, 0),
      transform: GradientRotation(progress * 2 * math.pi),
    );
    paint.shader = gradient.createShader(Offset.zero & size);

    final path = Path();
    final amp = size.height * 0.35;
    final freq = 2 * math.pi / size.width; // 1 full wave over width
    final phase = progress * 2 * math.pi;

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height / 2 + math.sin(freq * x + phase) * amp;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw 3 stacked waves with slight vertical offsets for richness
    canvas.save();
    for (int i = 0; i < 3; i++) {
      final dy = (i - 1) * (strokeWidth + 1);
      canvas.translate(0, dy.toDouble());
      canvas.drawPath(path, paint);
      canvas.translate(0, -dy.toDouble());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// A compact wave used in inline status (saving, tiny loaders, etc.).
class MiniWave extends StatelessWidget {
  final double size;
  final Color? color;
  const MiniWave({super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return WaveLoader(size: size, color: color ?? Colors.white70, strokeWidth: 1.6);
  }
}

/// A large-area shimmering placeholder for lists/panels.
class BigShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  const BigShimmer({super.key, this.width = 120, this.height = 16, this.borderRadius = const BorderRadius.all(Radius.circular(8))});

  @override
  State<BigShimmer> createState() => _BigShimmerState();
}

class _BigShimmerState extends State<BigShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ShimmerPainter(progress: _controller.value, borderRadius: widget.borderRadius),
          );
        },
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final BorderRadius borderRadius;
  _ShimmerPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final base = Paint()..color = Colors.white.withOpacity(0.06);
    canvas.drawRRect(rrect, base);

    final shimmer = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.00),
        AppColors.darkerAccent.withOpacity(0.30),
        Colors.white.withOpacity(0.00),
      ],
      stops: const [0.25, 0.5, 0.75],
      begin: Alignment(-1, 0),
      end: Alignment(1, 0),
      transform: GradientRotation(progress * 2 * math.pi),
    );
    final paint = Paint()..shader = shimmer.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.borderRadius != borderRadius;
  }
}
