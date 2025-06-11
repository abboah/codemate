import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

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
      // color: const Color(0xFF111118),
      color: Colors.black,
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
              // color: Color(0xFF6C5DD3),
              color: Colors.blue,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(
                            0.05,
                          ), // Very transparent glass effect
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Padding(
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
                                          //   color: Color(0xFFAAAAAA),
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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
                            ? Colors.blue
                            //const Color(0xFF6C5DD3)
                            : Colors.white,
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
