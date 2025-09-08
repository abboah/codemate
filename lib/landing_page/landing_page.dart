import 'dart:ui';

import 'package:codemate/landing_page/widgets/demo_video.dart';
import 'package:codemate/landing_page/widgets/features_section.dart';
import 'package:codemate/landing_page/widgets/footer.dart';
import 'package:codemate/landing_page/widgets/hero_section.dart';
import 'package:codemate/landing_page/widgets/navbar.dart';
import 'package:codemate/landing_page/widgets/testimonials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
    final ScrollController _scrollController = ScrollController();
    final GlobalKey _demoKey = GlobalKey();


  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    // Before accessing scroll controller
    return Scaffold(
      body: CustomScrollView(
        controller: 
        _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: NavBarDelegate(),
          ),
          SliverToBoxAdapter(
            key: const ValueKey('hero'),
            child: EnhancedHeroSection(onPressed: (){
              // Scroll to demo video section
              final demoContext = _demoKey.currentContext;
              if (demoContext != null) {
                Scrollable.ensureVisible(
                  demoContext,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  alignment: 0.1, // Position demo video near top of viewport
                );
              }
            },),
          ),
          SliverToBoxAdapter(
            key: _demoKey,
            child: const DemoVideoWidget(),
          ),
    SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.black),
              child: Divider(color: color.onSurface, indent: 0, endIndent: 0),
            ),
          ),
          SliverToBoxAdapter(
            key: const ValueKey('playground'),
            child: FeatureSection(
              title: "Experiment Freely in the Playground",
              description:
                  "Test ideas instantly in an interactive coding space. Prototype, tweak, and run code with AI-powered feedback — all without leaving your browser.",
              imagePath: "images/playground_canvas.png",
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
            key: const ValueKey('build'),
            child: FeatureSection(
              title: "Build Smarter with AI",
              description:
                  "Turn ideas into real projects with Robin, your AI coding copilot. From brainstorming features to generating production-ready code, Build helps you move from concept to completion faster.",
              imagePath: "images/build_ide.png",
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
            key: const ValueKey('learn'),
            child: FeatureSection(
              title: "Learn by Doing",
              description:
                  "Master coding concepts through guided lessons and hands-on challenges. Get personalized feedback, explore new topics, and grow your skills at your own pace.",
              imagePath: "images/learn_landing.png",
              isReversed: false,
            ),
          ),
          SliverToBoxAdapter(
            key: const ValueKey('testimonials'),
            child: TestimonialsSection(),
          ),
          //  SliverToBoxAdapter(child: PricingSection()),
          SliverToBoxAdapter(
            key: const ValueKey('footer'),
            child: Footer(),
          ),
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

    // Note: This is a simplified implementation
    // In a real implementation, you'd want proper state management
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