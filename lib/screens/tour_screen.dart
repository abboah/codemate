import 'dart:ui';

import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/home_screen.dart';
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

  final List<Map<String, dynamic>> _tourPages = [
    {
      'icon': Icons.waving_hand_rounded,
      'title': "Welcome to Robin!",
      'subtitle':
          "I'm your project builder and learning partner. Let's take a quick tour!",
      'color': Colors.blueAccent,
    },
    {
      'icon': Icons.construction_rounded,
      'title': "Build Mode",
      'subtitle':
          "Brainstorm ideas and build incredible things with an AI agent that can create and manage a full codebase for you.",
      'color': Colors.purpleAccent,
    },
    {
      'icon': Icons.school_rounded,
      'title': "Learn Mode",
      'subtitle':
          "Navigate complex courses for both programming languages and frameworks, with personalized guidance every step of the way.",
      'color': Colors.greenAccent,
    },
    {
      'icon': Icons.chat_bubble_rounded,
      'title': "AI Chat Buddy",
      'subtitle':
          "Whenever you need to talk through an idea or ask a question, I'm here to help. Think of me as your personal coding companion.",
      'color': Colors.orangeAccent,
    }
  ];

  Future<void> _completeTour() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('user_settings')
          .update({'has_completed_onboarding': true}).eq('user_id', userId);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => HomeScreen(profile: widget.profile)),
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
        ],
      ),
    );
  }

  Widget _buildAnimatedGlow() {
    final size = MediaQuery.of(context).size;
    final positions = [
      Alignment(-1.5, -0.8),
      Alignment(1.5, -0.5),
      Alignment(-1.5, 0.8),
      Alignment(1.5, 0.5),
    ];

    return AnimatedAlign(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: positions[_currentPage],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: size.width * 1.2,
        height: size.height * 0.8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _tourPages[_currentPage]['color'].withOpacity(0.5),
              Colors.black.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourPage(Map<String, dynamic> pageData, bool isCurrentPage) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: isCurrentPage ? 1.0 : 0.3,
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassIcon(icon: pageData['icon'], color: pageData['color']),
            const SizedBox(height: 50),
            AnimatedSlide(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              offset: Offset(0, isCurrentPage ? 0 : 0.2),
              child: Text(
                pageData['title'],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSlide(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              offset: Offset(0, isCurrentPage ? 0 : 0.2),
              child: Text(
                pageData['subtitle'],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ),
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
          // Back Button
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _GlassIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: _currentPage > 0
                  ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  : () {},
            ),
          ),

          // Dots Indicator
          Row(
            children: List.generate(_tourPages.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? _tourPages[_currentPage]['color']
                      : Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }),
          ),

          // Next/Finish Button
          ElevatedButton(
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
              foregroundColor: Colors.black,
              backgroundColor: _tourPages[_currentPage]['color'],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _currentPage < _tourPages.length - 1 ? 'Next' : 'Get Started',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GlassIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
        ),
      ),
    );
  }
}
