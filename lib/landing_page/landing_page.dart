import 'dart:async';
import 'dart:ui';

import 'package:codemate/auth/login_page.dart';
import 'package:codemate/landing_page/widgets/features_section.dart';
import 'package:codemate/landing_page/widgets/footer.dart';
import 'package:codemate/landing_page/widgets/hero_section.dart';
import 'package:codemate/landing_page/widgets/navbar.dart';
import 'package:codemate/landing_page/widgets/pricing.dart';
import 'package:codemate/landing_page/widgets/testimonials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverPersistentHeader(
            pinned: true,
            delegate: NavBarDelegate(),
          ),
          SliverToBoxAdapter(child: EnhancedHeroSection()),
          SliverToBoxAdapter(
            child: FeatureSection(
              title: "AI-Powered Code Completion",
              description:
                  "Our intelligent editor predicts your next move with uncanny accuracy, reducing keystrokes by 40% on average.",
              imagePath: "images/code_editor.png",
              isReversed: true,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.black),
              child: Divider(color: color.onSurface, indent: 0, endIndent: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: FeatureSection(
              title: "Real-Time Collaboration",
              description:
                  "Work simultaneously with teammates anywhere in the world with our low-latency collaborative editing.",
              imagePath: "images/code_editor.png",
              isReversed: false,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.black),
              child: Divider(color: color.onSurface, indent: 0, endIndent: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: FeatureSection(
              title: "Integrated Debugging",
              description:
                  "Identify and fix issues faster with our visual debugging tools and AI-assisted error detection.",
              imagePath: "images/code_editor.png",
              isReversed: true,
            ),
          ),
          SliverToBoxAdapter(child: TestimonialsSection()),
          SliverToBoxAdapter(child: PricingSection()),
          SliverToBoxAdapter(child: Footer()),
        ],
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient? gradient;
  final Color? borderColor;

  const GlassButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.gradient,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? Colors.transparent, width: 1),
        gradient: gradient,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;

  const GlassCard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF111118).withOpacity(0.7),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

class HoverScaleWidget extends StatefulWidget {
  final Widget child;
  final double scale;

  const HoverScaleWidget({Key? key, required this.child, this.scale = 1.05})
    : super(key: key);

  @override
  State<HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class IntersectionObserver {
  final Function(List<IntersectionObserverEntry>) callback;
  final double threshold;

  IntersectionObserver({required this.callback, this.threshold = 0.0});

  void observe(BuildContext context) {
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) return;

    final widget = context.widget as StatefulWidget;
    final state = (widget as dynamic).createState();

    void checkIntersection() {
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      final viewport = WidgetsBinding.instance.window.physicalSize;
      final visibleHeight = viewport.height - bounds.top;
      final ratio = visibleHeight / bounds.height;

      if (ratio >= threshold) {
        callback([
          IntersectionObserverEntry(
            target: context,
            isIntersecting: true,
            intersectionRatio: ratio,
          ),
        ]);
      }
    }

    state._checkIntersection = checkIntersection;
    WidgetsBinding.instance.addPostFrameCallback((_) => checkIntersection());
    WidgetsBinding.instance.addPersistentFrameCallback(
      (_) => checkIntersection(),
    );
  }
}

class IntersectionObserverEntry {
  final BuildContext target;
  final bool isIntersecting;
  final double intersectionRatio;

  const IntersectionObserverEntry({
    required this.target,
    required this.isIntersecting,
    required this.intersectionRatio,
  });
}
