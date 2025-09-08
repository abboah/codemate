import 'dart:ui';

import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/home_screen.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourScreen extends StatefulWidget {
  final UserProfile profile;
  const TourScreen({super.key, required this.profile});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  final List<Map<String, dynamic>> _tourPages = [
    {
      'icon': Icons.auto_awesome_rounded,
      'title': "Meet Your AI Partner",
      'subtitle':
          "Experience the future of development with Robin—your intelligent companion that transforms ideas into reality.",
      'features': [
        "✨ Instant project generation",
        "🎯 Personalized guidance",
        "⚡ Lightning-fast workflows",
      ],
      'color': const Color(0xFF6366F1),
      'gradient': [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
    },
    {
      'icon': Icons.rocket_launch_rounded,
      'title': "Build Faster & Smarter",
      'subtitle':
          "From concept to deployment—watch your ideas come to life with AI-powered development that understands your vision.",
      'features': [
        "🚀 Full-stack code generation",
        "🔧 Intelligent debugging",
        "📱 Multi-platform support",
      ],
      'color': const Color(0xFF8B5CF6),
      'gradient': [const Color(0xFFEC4899), const Color(0xFFEF4444)],
    },
    {
      'icon': Icons.psychology_rounded,
      'title': "Learn Like Never Before",
      'subtitle':
          "Master any technology with adaptive learning paths that evolve with you—from beginner to expert, seamlessly.",
      'features': [
        "🧠 Adaptive curriculum",
        "📚 Real-world projects",
        "🎓 Skill verification",
      ],
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF059669), const Color(0xFF0D9488)],
    },
    {
      'icon': Icons.rocket_launch_outlined,
      'title': "Prototype & Perfect",
      'subtitle':
          "Turn ideas into working apps in minutes. Build, test, and download real prototypes that you can run anywhere.",
      'features': [
        "⚡ Instant app creation",
        "� Live preview & testing",
        "� Download & run locally",
      ],
      'color': const Color(0xFFEF4444),
      'gradient': [const Color(0xFFF97316), const Color(0xFFF59E0B)],
    },
  ];

  Future<void> _completeTour() async {
    try {
      if (mounted) setState(() => _saving = true);
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('user_settings')
          .update({'has_completed_onboarding': true})
          .eq('user_id', userId);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(profile: widget.profile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedGlow(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _tourPages.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      final isCurrentPage = index == _currentPage;
                      return _buildTourPage(_tourPages[index], isCurrentPage);
                    },
                  ),
                ),
                _buildControls(),
              ],
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: AuroraPulseLoader(
                    size: 160,
                    baseColor: _tourPages[_currentPage]['color'],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedGlow() {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Primary animated gradient orb
        AnimatedPositioned(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
          left: _currentPage.isEven ? -size.width * 0.3 : size.width * 0.8,
          top: size.height * 0.1 + (_currentPage * 50),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            width: size.width * 1.2,
            height: size.width * 1.2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _tourPages[_currentPage]['gradient'][0].withOpacity(0.3),
                  _tourPages[_currentPage]['gradient'][1].withOpacity(0.15),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // Secondary floating orb
        AnimatedPositioned(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
          right: _currentPage.isOdd ? -size.width * 0.2 : size.width * 0.6,
          bottom: size.height * 0.2 + (_currentPage * 30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 1000),
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _tourPages[_currentPage]['color'].withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
        ),
        // Floating particles
        ...List.generate(6, (index) {
          final offset = (index * 0.2) + (_currentPage * 0.1);
          return AnimatedPositioned(
            duration: Duration(milliseconds: 1200 + (index * 100)),
            curve: Curves.easeInOutSine,
            left:
                (size.width * 0.2) +
                (index * size.width * 0.15) +
                (offset * 100),
            top: (size.height * 0.3) + (index * 60) + (offset * 80),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: 0.4 + (0.1 * index),
              child: Container(
                width: 4 + (index * 2),
                height: 4 + (index * 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _tourPages[_currentPage]['color'].withOpacity(0.6),
                  boxShadow: [
                    BoxShadow(
                      color: _tourPages[_currentPage]['color'].withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTourPage(Map<String, dynamic> pageData, bool isCurrentPage) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 600),
      opacity: isCurrentPage ? 1.0 : 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced glass icon with pulsing animation
            AnimatedScale(
              duration: const Duration(milliseconds: 600),
              scale: isCurrentPage ? 1.0 : 0.85,
              child: _GlassIcon(
                icon: pageData['icon'],
                color: pageData['color'],
                gradient: pageData['gradient'],
                isActive: isCurrentPage,
              ),
            ),
            const SizedBox(height: 48),

            // Title with staggered animation
            AnimatedSlide(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              offset: Offset(0, isCurrentPage ? 0 : 0.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: isCurrentPage ? 1.0 : 0.0,
                child: ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: pageData['gradient'],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                  child: Text(
                    pageData['title'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Subtitle with enhanced styling
            AnimatedSlide(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              offset: Offset(0, isCurrentPage ? 0 : 0.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: isCurrentPage ? 1.0 : 0.0,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Text(
                    pageData['subtitle'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Feature list with staggered animations
            ...pageData['features'].asMap().entries.map((entry) {
              final index = entry.key;
              final feature = entry.value;
              return AnimatedSlide(
                duration: Duration(milliseconds: (400 + (index * 100)).round()),
                curve: Curves.easeOutCubic,
                offset: Offset(0, isCurrentPage ? 0 : 0.5),
                child: AnimatedOpacity(
                  duration: Duration(
                    milliseconds: (300 + (index * 100)).round(),
                  ),
                  opacity: isCurrentPage ? 1.0 : 0.0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: pageData['color'].withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: pageData['color'].withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      feature,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button with enhanced styling
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedScale(
              scale: _currentPage > 0 ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 300),
              child: _GlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                color: _tourPages[_currentPage]['color'],
                onPressed:
                    _currentPage > 0
                        ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                        : () {},
              ),
            ),
          ),

          // Enhanced dots indicator with animations
          Row(
            children: List.generate(_tourPages.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: isActive ? 12 : 8,
                width: isActive ? 32 : 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient:
                      isActive
                          ? LinearGradient(
                            colors: _tourPages[_currentPage]['gradient'],
                          )
                          : null,
                  color: isActive ? null : Colors.grey.withOpacity(0.4),
                  boxShadow:
                      isActive
                          ? [
                            BoxShadow(
                              color: _tourPages[_currentPage]['color']
                                  .withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
              );
            }),
          ),

          // Enhanced Next/Finish Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _tourPages[_currentPage]['gradient'],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _tourPages[_currentPage]['color'].withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _tourPages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _completeTour();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_currentPage == _tourPages.length - 1) ...[
                    const Icon(Icons.auto_awesome_rounded, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _currentPage < _tourPages.length - 1
                        ? 'Next'
                        : 'Get Started',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_currentPage < _tourPages.length - 1) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final bool isActive;

  const _GlassIcon({
    required this.icon,
    required this.color,
    required this.gradient,
    required this.isActive,
  });

  @override
  State<_GlassIcon> createState() => _GlassIconState();
}

class _GlassIconState extends State<_GlassIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_GlassIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _pulseAnimation.value : 1.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow effect
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withOpacity(0.3),
                      widget.color.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
              // Glass container
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              widget.gradient[0].withOpacity(0.2),
                              widget.gradient[1].withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: widget.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                          child: Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _isHovered ? 1.05 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      _isHovered
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        widget.color?.withOpacity(0.3) ??
                        Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow:
                      _isHovered
                          ? [
                            BoxShadow(
                              color:
                                  widget.color?.withOpacity(0.3) ??
                                  Colors.white.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                          : null,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color ?? Colors.white70,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
