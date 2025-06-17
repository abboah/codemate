import 'package:codemate/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

class EnhancedHeroSection extends StatefulWidget {
  const EnhancedHeroSection({super.key});

  @override
  State<EnhancedHeroSection> createState() => _EnhancedHeroSectionState();
}

class _EnhancedHeroSectionState extends State<EnhancedHeroSection>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideUpAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;

  final List<Particle> _particles = [];
  final int _particleCount = 50;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    _startAnimations();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Staggered animations for premium feel
    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutQuart),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _generateParticles() {
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(Particle());
    }
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _mainController.forward();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 1024;
    final isNotDesktop = screenWidth < 1480;
    //  final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Container(
      width: double.infinity,
      height: math.max(screenHeight, 700),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.0,
          colors: [
            Color(0xFF000000),
            Color(0xFF0A0A0A),
            Color(0xFF121212),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Animated particle background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particles, _particleController.value),
                size: Size(screenWidth, screenHeight),
              );
            },
          ),

          // Dynamic gradient orbs
          ..._buildGradientOrbs(screenWidth, screenHeight),

          // Mesh gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF2563EB).withOpacity(0.03),
                  const Color(0xFF3B82F6).withOpacity(0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Main content
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20.0 : (isTablet ? 60.0 : 120.0),
                  vertical: isMobile ? 40.0 : 80.0,
                ),
                child: AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideUpAnimation.value),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeInAnimation.value,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Spacer(flex: 1),
                                    // Main headline with advanced effects
                                    _buildMainHeadline(isMobile, isTablet),

                                    SizedBox(height: isMobile ? 20 : 32),

                                    // Subtitle with typewriter effect
                                    _buildSubtitle(isMobile, isTablet),

                                    SizedBox(height: isMobile ? 24 : 40),

                                    // Feature tags with staggered animation
                                    _buildFeatureTags(isMobile),

                                    SizedBox(height: isMobile ? 32 : 48),

                                    // CTA buttons with premium effects
                                    _buildCTAButtons(isMobile),

                                    SizedBox(height: isMobile ? 16 : 24),

                                    // Social proof
                                    _buildSocialProof(isMobile),

                                    Spacer(flex: 1),
                                  ],
                                ),
                              ),
                              if (!isMobile && !isTablet && !isNotDesktop)
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      // Floating code preview (desktop only)
                                      _buildCodePreview(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Scroll indicator
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatingAnimation.value),
                  child: const Center(child: ScrollIndicator()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeadline(bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overline text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              width: 1,
            ),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2563EB).withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI-POWERED LEARNING',
                style: TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isMobile ? 16 : 24),

        // Main headline
        ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [
                  Colors.white,
                  Color(0xFFE5E7EB),
                  Color(0xFF3B82F6),
                  Colors.white,
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ).createShader(bounds),
          child: Text(
            isMobile
                ? 'Master Coding\nWith AI Guidance'
                : 'Master Coding With\nIntelligent AI Guidance',
            style: TextStyle(
              fontSize: isMobile ? 36.0 : (isTablet ? 48.0 : 64.0),
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle(bool isMobile, bool isTablet) {
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 650),
      child: Text(
        'Transform from complete beginner to confident developer with our revolutionary AI mentor. Experience personalized learning that adapts to your pace and style.',
        style: TextStyle(
          color: const Color(0xFFD1D5DB),
          fontSize: isMobile ? 16.0 : (isTablet ? 18.0 : 20.0),
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildFeatureTags(bool isMobile) {
    final features = [
      {'icon': '🧠', 'text': 'AI-Powered Learning'},
      {'icon': '⚡', 'text': 'Instant Feedback'},
      {'icon': '🎯', 'text': 'Personalized Path'},
      {'icon': '🚀', 'text': 'Real Projects'},
    ];

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: isMobile ? 8 : 16,
        runSpacing: 12,
        children:
            features.asMap().entries.map((entry) {
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 800 + (entry.key * 200)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: _buildFeatureChip(
                      entry.value['icon']!,
                      entry.value['text']!,
                      isMobile,
                    ),
                  );
                },
              );
            }).toList(),
      ),
    );
  }

  Widget _buildFeatureChip(String icon, String text, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1F2937).withOpacity(0.8),
            const Color(0xFF374151).withOpacity(0.4),
          ],
        ),
        border: Border.all(color: const Color(0xFF374151), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: isMobile ? 14 : 16)),
          SizedBox(width: isMobile ? 6 : 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButtons(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                children: [
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: PremiumButton(
                            onPressed: () {
                              // Navigate to signup
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LoginPage()),
                              );
                            },
                            text: 'Start Learning Free',
                            isPrimary: true,
                            width: double.infinity,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Secondary CTA
                  SizedBox(
                    width: double.infinity,
                    child: PremiumButton(
                      onPressed: () {
                        // Show demo
                      },
                      text: 'Watch Demo',
                      isPrimary: false,
                      width: double.infinity,
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  // Primary CTA
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: PremiumButton(
                          onPressed: () {
                            // Navigate to signup
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                            );
                          },
                          text: 'Start Learning Free',
                          isPrimary: true,
                          width: 220,
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 20),

                  // Secondary CTA
                  PremiumButton(
                    onPressed: () {
                      // Show demo
                    },
                    text: 'Watch Demo',
                    isPrimary: false,
                    width: 160,
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildSocialProof(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar stack
              SizedBox(
                width: 100,
                height: 32,
                child: Stack(
                  children: List.generate(4, (index) {
                    return Positioned(
                      left: index * 20.0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF374151),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1F2937), Color(0xFF374151)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '12,847+ developers started this month',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            color: const Color(0xFF3B82F6),
                            size: isMobile ? 14 : 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '4.9/5 (2,341 reviews)',
                          style: TextStyle(
                            color: const Color(0xFF9CA3AF),
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodePreview() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _floatingAnimation.value * 0.5,
            _floatingAnimation.value,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
            margin: const EdgeInsets.only(left: 50),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1F2937).withOpacity(0.9),
                  const Color(0xFF111827).withOpacity(0.9),
                ],
              ),
              border: Border.all(color: const Color(0xFF374151), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: const CodePreviewWidget(),
          ),
        );
      },
    );
  }

  List<Widget> _buildGradientOrbs(double width, double height) {
    return [
      // Top-right orb
      AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Positioned(
            right: -100 + _floatingAnimation.value,
            top: -100 - _floatingAnimation.value,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withOpacity(0.15),
                    const Color(0xFF3B82F6).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),

      // Bottom-left orb
      AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Positioned(
            left: -200 - _floatingAnimation.value,
            bottom: -200 + _floatingAnimation.value,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E40AF).withOpacity(0.1),
                    const Color(0xFF2563EB).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          );
        },
      ),

      // Center orb
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Positioned(
            right: width * 0.3,
            top: height * 0.6,
            child: Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

// Particle system for dynamic background
class Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double size;
  late Color color;
  late double opacity;

  Particle() {
    reset();
  }

  void reset() {
    x = math.Random().nextDouble();
    y = math.Random().nextDouble();
    vx = (math.Random().nextDouble() - 0.5) * 0.01;
    vy = (math.Random().nextDouble() - 0.5) * 0.01;
    size = math.Random().nextDouble() * 2 + 0.5;
    opacity = math.Random().nextDouble() * 0.3 + 0.1;

    final colors = [
      Colors.white,
      const Color(0xFF3B82F6),
      const Color(0xFF2563EB),
      const Color(0xFFE5E7EB),
    ];
    color = colors[math.Random().nextInt(colors.length)];
  }

  void update() {
    x += vx;
    y += vy;

    if (x < 0 || x > 1 || y < 0 || y > 1) {
      reset();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      particle.update();

      final paint =
          Paint()
            ..color = particle.color.withOpacity(particle.opacity)
            ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Premium button component
class PremiumButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isPrimary;
  final double? width;

  const PremiumButton({
    Key? key,
    required this.onPressed,
    required this.text,
    this.isPrimary = true,
    this.width,
  }) : super(key: key);

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.width,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient:
                      widget.isPrimary
                          ? LinearGradient(
                            colors:
                                _isHovered
                                    ? [
                                      const Color(0xFF1E40AF),
                                      const Color(0xFF2563EB),
                                    ]
                                    : [Colors.lightBlue, Colors.blueAccent],
                          )
                          : null,
                  color: widget.isPrimary ? null : const Color(0xFF1F2937),
                  border:
                      widget.isPrimary
                          ? null
                          : Border.all(
                            color: const Color(0xFF374151),
                            width: 1,
                          ),
                  boxShadow:
                      widget.isPrimary
                          ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.3),
                              blurRadius: _isHovered ? 20 : 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                          ]
                          : null,
                ),
                child: Center(
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Scroll indicator component
class ScrollIndicator extends StatefulWidget {
  const ScrollIndicator({Key? key}) : super(key: key);

  @override
  State<ScrollIndicator> createState() => _ScrollIndicatorState();
}

class _ScrollIndicatorState extends State<ScrollIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Scroll to explore',
          style: TextStyle(
            color: const Color(0xFF9CA3AF),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animation.value),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: const Color(0xFF9CA3AF),
                size: 24,
              ),
            );
          },
        ),
      ],
    );
  }
}

// Code preview widget
class CodePreviewWidget extends StatelessWidget {
  const CodePreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Window controls
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 12,

                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF28CA42),
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              Text(
                'main.py',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCodeLine('def', ' hello_world():'),
                _buildCodeLine('    print(', '"Hello, World!"', ')'),
                _buildCodeLine(''),
                _buildCodeLine('# AI suggests:', ' Add error handling'),
                _buildCodeLine('try', ':'),
                _buildCodeLine('    hello_world()'),
                _buildCodeLine('except', ' Exception', ' as', ' e:'),
                _buildCodeLine('    print(', 'f"Error: {e}"', ')'),
                _buildCodeLine(''),
                _buildCodeLine('def', ' add(a, b):'),
                _buildCodeLine('    return', ' a + b'),
                _buildCodeLine(''),
                _buildCodeLine('# AI suggests:', ' Check for None inputs'),
                _buildCodeLine('def', ' safe_add(a, b):'),
                _buildCodeLine('    if', ' a is None or b is None:'),
                _buildCodeLine('        return', ' 0'),
                _buildCodeLine('    return', ' a + b'),
                _buildCodeLine(''),
                _buildCodeLine('result =', ' safe_add(5, 10)'),
                _buildCodeLine('print(', '"Result:", result', ')'),
                _buildCodeLine(''),
                _buildCodeLine('# AI suggests:', ' Use type hints'),
                _buildCodeLine('def', ' greet(name: str) -> str:'),
                _buildCodeLine('    return', ' f"Hi, {name}!"'),
                _buildCodeLine('print(', 'greet("Dev")', ')'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeLine(
    String keyword, [
    String? text,
    String? operator,
    String? variable,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            keyword,
            style: const TextStyle(
              color: Color(0xFF9C88FF),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          if (text != null)
            Text(
              text,
              style: TextStyle(
                color:
                    text.startsWith('"')
                        ? const Color(0xFF68D391)
                        : Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
          if (operator != null)
            Text(
              operator,
              style: const TextStyle(
                color: Color(0xFF9C88FF),
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          if (variable != null)
            Text(
              variable,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

// Glassmorphism container component
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;

  const GlassmorphismContainer({
    Key? key,
    required this.child,
    this.borderRadius = 16,
    this.opacity = 0.1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.white.withOpacity(opacity * 0.5),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

// Custom hover effect widget
class HoverScaleWidget extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const HoverScaleWidget({
    Key? key,
    required this.child,
    this.scale = 1.05,
    this.duration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  State<HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<HoverScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

// Magnetic button effect
class MagneticButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double magneticDistance;

  const MagneticButton({
    Key? key,
    required this.child,
    this.onTap,
    this.magneticDistance = 50.0,
  }) : super(key: key);

  @override
  State<MagneticButton> createState() => _MagneticButtonState();
}

class _MagneticButtonState extends State<MagneticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerEvent details, BoxConstraints constraints) {
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final distance = (details.localPosition - center).distance;

    if (distance < widget.magneticDistance) {
      final direction = (details.localPosition - center).direction;
      final strength = 1 - (distance / widget.magneticDistance);
      setState(() {
        _offset = Offset(
          math.cos(direction) * strength * 10,
          math.sin(direction) * strength * 10,
        );
      });
    }
  }

  void _onPointerExit() {
    setState(() {
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (event) => _onPointerMove(event, constraints),
          onExit: (_) => _onPointerExit(),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              transform: Matrix4.identity()..translate(_offset.dx, _offset.dy),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

// Animated gradient text
class AnimatedGradientText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final Duration duration;

  const AnimatedGradientText({
    Key? key,
    required this.text,
    required this.style,
    this.colors = const [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
    ],
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<AnimatedGradientText> createState() => _AnimatedGradientTextState();
}

class _AnimatedGradientTextState extends State<AnimatedGradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.colors,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                (_animation.value - 0.1).clamp(0.0, 1.0),
                (_animation.value + 0.1).clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(color: Colors.white),
          ),
        );
      },
    );
  }
}

// // Floating elements for enhanced visual appeal
// class FloatingElements extends StatefulWidget {
//   const FloatingElements({Key? key}) : super(key: key);

//   @override
//   State<FloatingElements> createState() => _FloatingElementsState();
// }

// class _FloatingElementsState extends State<FloatingElements>
//     with TickerProviderStateMixin {
//   late List<AnimationController> _controllers;
//   late List<Animation<double>> _animations;

//   @override
//   void initState() {
//     super.initState();
//     _controllers = List.generate(5, (index) {
//       return AnimationController(
//         duration: Duration(seconds: 3 + index),
//         vsync: this,
//       )..repeat(reverse: true);
//     });

//     _animations =
//         _controllers.map((controller) {
//           return Tween<double>(begin: -20, end: 20).animate(
//             CurvedAnimation(parent: controller, curve: Curves.easeInOut),
//           );
//         }).toList();
//   }

//   @override
//   void dispose() {
//     for (final controller in _controllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: List.generate(5, (index) {
//         return AnimatedBuilder(
//           animation: _animations[index],
//           builder: (context, child) {
//             return Positioned(
//               left: 100.0 * index + 50,
//               top: 100.0 + _animations[index].value,
//               child: Opacity(
//                 opacity: 0.1,
//                 child: Icon(
//                   [
//                     Icons.code,
//                     Icons.lightbulb_outline,
//                     Icons.rocket_launch,
//                     Icons.psychology,
//                     Icons.trending_up,
//                   ][index],
//                   size: 30 + (index * 10),
//                   color:
//                       [
//                         const Color(0xFF6366F1),
//                         const Color(0xFF8B5CF6),
//                         const Color(0xFF06B6D4),
//                         const Color(0xFF10B981),
//                         const Color(0xFFF59E0B),
//                       ][index],
//                 ),
//               ),
//             );
//           },
//         );
//       }),
//     );
//   }
// }
