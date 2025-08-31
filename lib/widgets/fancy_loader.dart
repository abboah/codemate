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

/// A dedicated, refined loader for "thinking" states in chat.
/// Shows 4 softly glowing dots with a staggered vertical bounce and shimmer.
class ThinkingDotsLoader extends StatefulWidget {
  final double size; // overall width; dot size scales relatively
  final Color? color; // base color for glow

  const ThinkingDotsLoader({super.key, this.size = 48, this.color});

  @override
  State<ThinkingDotsLoader> createState() => _ThinkingDotsLoaderState();
}

class _ThinkingDotsLoaderState extends State<ThinkingDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _bounces;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Create 4 staggered intervals for bounce animations
    _bounces = List.generate(4, (i) {
      final start = i * 0.12;
      final end = start + 0.6; // overlap a bit for smoothness
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final base = widget.color ?? AppColors.darkerAccent;
  final double dot = math.max(4.0, math.min(10.0, widget.size / 8));
    final spacing = dot * 1.5;
    final totalWidth = dot * 4 + spacing * 3;
    return SizedBox(
      width: totalWidth,
      height: dot * 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) => _buildDot(base, dot, _bounces[i])).separated(const SizedBox(width: 8)),
      ),
    );
  }

  Widget _buildDot(Color base, double size, Animation<double> a) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) {
        // y goes up and down; also modulate opacity
        final y = (-(a.value * 1.0 - 0.5).abs() + 0.5) * 6.0; // 0..6..0
        final op = 0.5 + 0.5 * (a.value);
        final color = base.withOpacity(op.clamp(0.3, 1.0));
        return Transform.translate(
          offset: Offset(0, -y),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.3),
                ],
              ),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 0.5),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension on List<Widget> {
  List<Widget> separated(Widget separator) {
    if (isEmpty) return this;
    final out = <Widget>[];
    for (var i = 0; i < length; i++) {
      out.add(this[i]);
      if (i != length - 1) out.add(separator);
    }
    return out;
  }
}
