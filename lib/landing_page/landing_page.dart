import 'dart:async';
import 'dart:ui';

import 'package:codemate/auth/login_page.dart';
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
            delegate: _NavBarDelegate(),
          ),
          SliverToBoxAdapter(child: HeroSection()),
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
              decoration: BoxDecoration(color: const Color(0xFF0A0A0F)),
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
              decoration: BoxDecoration(color: const Color(0xFF0A0A0F)),
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
          //  SliverToBoxAdapter(child: PricingSection()),
          SliverToBoxAdapter(child: Footer()),
        ],
      ),
    );
  }
}

class _NavBarDelegate extends SliverPersistentHeaderDelegate {
  const _NavBarDelegate();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final color = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: NavBar(transparency: shrinkOffset / maxExtent),
    );
  }

  @override
  double get maxExtent => 80;

  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant _NavBarDelegate oldDelegate) => false;
}

class NavBar extends StatefulWidget {
  final double transparency;

  const NavBar({Key? key, this.transparency = 0}) : super(key: key);

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<String> _navItems = [
    'Features',
    'Solutions',
    'Resources',
    'Pricing',
    'Login',
  ];
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final bgColor = Color.lerp(
      const Color(0xFF111118),
      const Color(0xFF000000),
      widget.transparency,
    );

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 48.0,
        vertical: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HoverScaleWidget(
            scale: 1.1,
            child: Row(
              children: [
                const Icon(
                  Icons.flutter_dash,
                  color: Colors.white,
                  // color: Color(0xFF6C5DD3),
                  size: 35,
                ),
                const SizedBox(width: 8),
                Text(
                  'Robin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _showMobileMenu(context),
            )
          else
            Row(
              children: [
                ...List.generate(_navItems.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: InkWell(
                      onHover: (hovering) {
                        setState(() {
                          _hoveredIndex = hovering ? index : -1;
                          hovering
                              ? _controller.forward()
                              : _controller.reverse();
                        });
                      },
                      onTap: () {},
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _navItems[index],
                            style: TextStyle(
                              color:
                                  _hoveredIndex == index
                                      ? const Color(0xFF6C5DD3)
                                      : Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight:
                                  _hoveredIndex == index
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (_hoveredIndex == index)
                            Container(
                              height: 2,
                              width: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF06B6D4),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 24),
                HoverScaleWidget(
                  scale: 1.05,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoginPage()),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0,
                        // vertical: 14.0,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Center(
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._navItems
                    .map(
                      (item) => ListTile(
                        title: Text(
                          item,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 16),
                GlassButton(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _translateAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [const Color(0xFF0A0A0F), Colors.black],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -100,
            top: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C5DD3).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -150,
            bottom: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E90FF).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24.0 : 120.0,
              vertical: isMobile ? 80.0 : 120.0,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _translateAnimation.value),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback:
                              (bounds) => const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                              ).createShader(bounds),
                          child: Text(
                            'Your Coding Journey Starts Here',
                            style: TextStyle(
                              fontSize: isMobile ? 32.0 : 56.0,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isMobile ? double.infinity : 600,
                          ),
                          child: const Text(
                            'New to coding? Perfect! Robin is designed to help beginners learn faster and build amazing projects. Our AI assistant guides you every step of the way, making programming fun and easy to understand.',
                            style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 18.0,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Encouraging features for beginners
                        Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            _buildFeatureChip('✨ Beginner-Friendly'),
                            _buildFeatureChip('🚀 Learn as You Code'),
                            _buildFeatureChip('💡 Smart Hints'),
                            _buildFeatureChip('🎯 Zero Experience Needed'),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Single call-to-action button
                        HoverScaleWidget(
                          scale: 1.05,
                          child: GlassButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LoginPage()),
                              );
                            },
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C5DD3), Color(0xFF1E90FF)],
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: const Text(
                                'Start Coding Today - It\'s Free!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Reassuring text for nervous beginners
                        const Text(
                          'Join thousands of new developers who started their journey with Robin',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14.0,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (!isMobile) ...[
                          // const SizedBox(height: 80),
                          // Center(
                          //   child: Container(
                          //     width: 800,
                          //     height: 400,
                          //     decoration: BoxDecoration(
                          //       borderRadius: BorderRadius.circular(16),
                          //       boxShadow: [
                          //         BoxShadow(
                          //           color: const Color(
                          //             0xFF6C5DD3,
                          //           ).withOpacity(0.3),
                          //           blurRadius: 40,
                          //           spreadRadius: 10,
                          //         ),
                          //       ],
                          //     ),
                          //     child: ClipRRect(
                          //       borderRadius: BorderRadius.circular(16),
                          //       child: Image.asset(
                          //         'images/code_editor_preview.png',
                          //         fit: BoxFit.cover,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5DD3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C5DD3).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C5DD3),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class FeatureSection extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final bool isReversed;

  const FeatureSection({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.isReversed,
  });

  @override
  State<FeatureSection> createState() => _FeatureSectionState();
}

class _FeatureSectionState extends State<FeatureSection> {
  final GlobalKey _key = GlobalKey();
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initIntersectionObserver(),
    );
  }

  void _initIntersectionObserver() {
    final intersectionObserver = IntersectionObserver(
      callback: (entries) {
        final entry = entries.first;
        if (entry.isIntersecting && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      threshold: 0.1,
    );
    intersectionObserver.observe(_key.currentContext!);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      key: _key,
      color: const Color(0xFF0A0A0F),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 120.0,
        vertical: 100,
      ),
      child: AnimatedOpacity(
        opacity: _isVisible ? 1 : 0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 800),
          padding: EdgeInsets.only(top: _isVisible ? 0 : 50),
          curve: Curves.easeOut,
          child:
              isMobile
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextContent(),
                      const SizedBox(height: 40),
                      _buildImage(),
                    ],
                  )
                  : Row(
                    children:
                        widget.isReversed
                            ? [
                              Expanded(child: _buildImage()),
                              const SizedBox(width: 80),
                              Expanded(child: _buildTextContent()),
                            ]
                            : [
                              Expanded(child: _buildTextContent()),
                              const SizedBox(width: 80),
                              Expanded(child: _buildImage()),
                            ],
                  ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Color(0xFF6C5DD3), Color(0xFF1E90FF)],
              ).createShader(bounds),
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 36.0,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.description,
          style: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 18.0,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        HoverScaleWidget(
          scale: 1.03,
          child: GlassButton(
            onPressed: () {},
            borderColor: const Color(0xFF6C5DD3),
            child: const Text(
              'Learn More',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5DD3).withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          widget.imagePath,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class TestimonialsSection extends StatefulWidget {
  const TestimonialsSection({Key? key}) : super(key: key);

  @override
  State<TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<TestimonialsSection> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_updatePage);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _autoScroll());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  void _updatePage() {
    setState(() => _currentPage = _pageController.page!.round());
  }

  void _autoScroll() {
    if (_currentPage < testimonials.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  final List<Map<String, String>> testimonials = [
    {
      'name': 'Sarah Johnson',
      'role': 'Senior Developer at Google',
      'quote':
          'Robin has transformed how our team collaborates. The AI suggestions are uncannily accurate.',
      'avatar': 'images/avatar.png',
    },
    {
      'name': 'Michael Chen',
      'role': 'CTO at TechStart',
      'quote':
          'We saw a 30% increase in developer productivity after switching to Robin.',
      'avatar': 'images/avatar.png',
    },
    {
      'name': 'Emma Rodriguez',
      'role': 'Lead Engineer at Meta',
      'quote':
          'The debugging tools alone are worth the price. A game-changer for complex systems.',
      'avatar': 'images/avatar.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF111118),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 120.0,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'TRUSTED BY INDUSTRY LEADERS',
            style: TextStyle(
              color: Color(0xFF6C5DD3),
              fontSize: 14.0,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'What Developers Say',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: isMobile ? 440 : 320,
            width: double.infinity,
            child: PageView.builder(
              controller: _pageController,
              itemCount: testimonials.length,
              itemBuilder: (context, index) {
                final testimonial = testimonials[index];
                final scale = _currentPage == index ? 1.0 : 0.9;

                return AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  scale: scale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: AssetImage(
                                    testimonial['avatar']!,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Flexible(
                                  child: Text(
                                    '"${testimonial['quote']!}"',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    testimonial['name']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    testimonial['role']!,
                                    style: const TextStyle(
                                      color: Color(0xFFAAAAAA),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(testimonials.length, (index) {
              return GestureDetector(
                onTap:
                    () => _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    ),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? const Color(0xFF6C5DD3)
                            : Colors.white.withOpacity(0.2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class PricingSection extends StatelessWidget {
  const PricingSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF0A0A0F),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 120.0,
        vertical: 100,
      ),
      child: Column(
        children: [
          const Text(
            'SIMPLE, TRANSPARENT PRICING',
            style: TextStyle(
              color: Color(0xFF6C5DD3),
              fontSize: 14.0,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start for free, upgrade when you need more power',
            style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 18.0),
          ),
          const SizedBox(height: 60),
          isMobile
              ? Column(
                children: [
                  _buildPricingCard(
                    title: 'Starter',
                    price: 'Free',
                    features: [
                      'Basic AI suggestions',
                      'Single project',
                      'Community support',
                    ],
                    isFeatured: false,
                  ),
                  const SizedBox(height: 30),
                  _buildPricingCard(
                    title: 'Pro',
                    price: '\$15/mo',
                    features: [
                      'Advanced AI',
                      'Unlimited projects',
                      'Priority support',
                      'Team collaboration',
                    ],
                    isFeatured: true,
                  ),
                  const SizedBox(height: 30),
                  _buildPricingCard(
                    title: 'Enterprise',
                    price: 'Custom',
                    features: [
                      'Everything in Pro',
                      'Dedicated instance',
                      'SLA guarantees',
                      'Custom integrations',
                    ],
                    isFeatured: false,
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPricingCard(
                      title: 'Starter',
                      price: 'Free',
                      features: [
                        'Basic AI suggestions',
                        'Single project',
                        'Community support',
                      ],
                      isFeatured: false,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: _buildPricingCard(
                      title: 'Pro',
                      price: '\$15/mo',
                      features: [
                        'Advanced AI',
                        'Unlimited projects',
                        'Priority support',
                        'Team collaboration',
                      ],
                      isFeatured: true,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: _buildPricingCard(
                      title: 'Enterprise',
                      price: 'Custom',
                      features: [
                        'Everything in Pro',
                        'Dedicated instance',
                        'SLA guarantees',
                        'Custom integrations',
                      ],
                      isFeatured: false,
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 60),
          Center(
            child: HoverScaleWidget(
              scale: 1.03,
              child: GlassButton(
                onPressed: () {},
                borderColor: const Color(0xFF6C5DD3),
                child: const Text(
                  'Compare All Features',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isFeatured,
  }) {
    return HoverScaleWidget(
      scale: 1.03,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: isFeatured ? const Color(0xFF111118) : const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFeatured ? const Color(0xFF6C5DD3) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (isFeatured)
              BoxShadow(
                color: const Color(0xFF6C5DD3).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback:
                  (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C5DD3), Color(0xFF1E90FF)],
                  ).createShader(bounds),
              child: Text(
                price,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ...features
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: const Color(0xFF6C5DD3),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          feature,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 30),
            GlassButton(
              onPressed: () {},
              gradient:
                  isFeatured
                      ? const LinearGradient(
                        colors: [Color(0xFF6C5DD3), Color(0xFF1E90FF)],
                      )
                      : null,
              borderColor:
                  isFeatured ? Colors.transparent : const Color(0xFF6C5DD3),
              child: Text(
                isFeatured ? 'Get Started' : 'Try Free',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isFeatured ? Colors.white : const Color(0xFF6C5DD3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF000000),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 120.0,
        vertical: 60,
      ),
      child: Column(
        children: [
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogoSection(),
                  const SizedBox(height: 40),
                  _buildFooterLinks(),
                  const SizedBox(height: 40),
                  _buildSocialLinks(),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLogoSection(),
                  _buildFooterLinks(),
                  _buildSocialLinks(),
                ],
              ),
          const SizedBox(height: 60),
          const Divider(color: Color(0xFF333333)),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '© 2025 Robin. All rights reserved.',
                style: TextStyle(color: Color(0xFFAAAAAA)),
              ),
              if (!isMobile) ...[
                HoverScaleWidget(
                  scale: 1.05,
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                ),
                HoverScaleWidget(
                  scale: 1.05,
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                ),
                HoverScaleWidget(
                  scale: 1.05,
                  child: const Text(
                    'Cookie Policy',
                    style: TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flutter_dash, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              'Robin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'The future of developer tools',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
      ],
    );
  }

  Widget _buildFooterLinks() {
    final links = {
      'Product': ['Features', 'Pricing', 'Integrations', 'Roadmap'],
      'Resources': ['Documentation', 'Tutorials', 'Blog', 'Community'],
      'Company': ['About', 'Careers', 'Contact', 'Press'],
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          links.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...entry.value
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HoverScaleWidget(
                            scale: 1.05,
                            child: Text(
                              item,
                              style: const TextStyle(color: Color(0xFFAAAAAA)),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSocialLinks() {
    final socialIcons = [
      Icons.facebook,
      // Icons.twitter,
      // Icons.linkedin,
      Icons.reddit,
      Icons.discord,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Follow Us',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children:
              socialIcons.map((icon) {
                return HoverScaleWidget(
                  scale: 1.2,
                  child: IconButton(
                    icon: Icon(icon, color: const Color(0xFFAAAAAA)),
                    onPressed: () {},
                  ),
                );
              }).toList(),
        ),
      ],
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
