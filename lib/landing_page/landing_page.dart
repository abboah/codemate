import 'package:flutter/material.dart';

class HoverPopWidget extends StatefulWidget {
  final Widget child;
  const HoverPopWidget({Key? key, required this.child}) : super(key: key);

  @override
  State<HoverPopWidget> createState() => _HoverPopWidgetState();
}

class _HoverPopWidgetState extends State<HoverPopWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedScale(
        scale: _isHovered ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: const [
            NavBar(),
            HeroSection(),
            AICodeEditorSection(isReversed: false),
            AICodeEditorSection(isReversed: true),
            AICodeEditorSection(isReversed: false),
            AICodeEditorSection(isReversed: true),
            TestimonialsSection(),
            Footer(),
          ],
        ),
      ),
    );
  }
}

class NavBar extends StatelessWidget {
  const NavBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF202124),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('images/projectx_logo.png', height: 25),
              const SizedBox(width: 8),
              if (!isMobile)
                const Text(
                  'Robin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                // Show mobile menu
              },
            )
          else
            Row(
              children: [
                _navItem('My Projects'),
                _navItem('Learn'),
                _navItem('Courses'),
                _navItem('Coding Assistant'),
                _navItem('Dashboard'),
                _navItem('Log In'),
                HoverPopWidget(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Download'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _navItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: HoverPopWidget(
        child: TextButton(
          onPressed: () => print("Clicked"),

          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('images/hero_bg.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.7),
            BlendMode.darken,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: isMobile ? 48.0 : 80.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Empowering Developers Through Interactive Learning',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 28.0 : 36.0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            constraints: BoxConstraints(maxWidth: isMobile ? 400 : 600),
            child: const Text(
              'Robin enhances your coding experience with interactive tools that simplify learning and boost productivity for every developer.',
              style: TextStyle(color: Colors.white, fontSize: 16.0),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          HoverPopWidget(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Download Robin'),
            ),
          ),
          const SizedBox(height: 48),
          Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? screenWidth * 0.9 : screenWidth * 0.8,
            ),
            child: Image.asset(
              'images/code_editor_preview.png',
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}

class AICodeEditorSection extends StatelessWidget {
  final bool isReversed;

  const AICodeEditorSection({Key? key, required this.isReversed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: 48.0,
      ),
      child:
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildText(),
                  const SizedBox(height: 24),
                  _buildImage(),
                ],
              )
              : Row(
                children:
                    isReversed
                        ? [
                          Expanded(child: _buildImage()),
                          const SizedBox(width: 48),
                          Expanded(child: _buildText()),
                        ]
                        : [
                          Expanded(child: _buildText()),
                          const SizedBox(width: 48),
                          Expanded(child: _buildImage()),
                        ],
              ),
    );
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Our AI-native code editor offers real-time suggestions.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
          style: TextStyle(color: Colors.white70, fontSize: 16.0),
        ),
      ],
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset('images/code_editor.png', width: double.infinity),
    );
  }
}

class TestimonialsSection extends StatefulWidget {
  const TestimonialsSection({Key? key}) : super(key: key);

  @override
  State<TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<TestimonialsSection> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      int next = _pageController.page!.round();
      if (_currentPage != next) {
        setState(() {
          _currentPage = next;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final testimonials = [
      _testimonialItem('Rick Wright', 'Developer at Google'),
      _testimonialItem('Rick Wright', 'Executive Developer'),
      _testimonialItem('Rick Wright', 'Technical Architect'),
    ];

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: 48.0,
      ),
      child: Column(
        children: [
          const Text(
            'TESTIMONIALS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.0,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What Our Users Say',
            style: TextStyle(
              color: Color(0xFFBFB06C),
              fontSize: isMobile ? 28.0 : 36.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 220,
            child:
                isMobile
                    ? PageView.builder(
                      controller: _pageController,
                      itemCount: testimonials.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: testimonials[index],
                        );
                      },
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: testimonials,
                    ),
          ),
          if (isMobile) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _testimonialItem(String name, String role) {
    return HoverPopWidget(
      child: Container(
        width: 300,
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundImage: AssetImage('images/avatar.png'),
            ),
            const SizedBox(height: 16),
            const Text(
              '"ProjectX has revolutionized\nmy development workflow!"',
              style: TextStyle(color: Colors.white, fontSize: 14.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: Color(0xFFBFB06C),
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(role, style: TextStyle(color: Colors.white70, fontSize: 12.0)),
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
      color: const Color(0xFF202124),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 32.0,
        vertical: 40.0,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('images/projectx_logo.png', height: 24),
              Row(
                children: [
                  _footerLink('Terms'),
                  _footerLink('Support'),
                  _footerLink('Privacy'),
                  _footerLink('English'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerLinkSection(
                  'Terms of Service',
                  'Privacy Policy',
                  'Security',
                ),
                const SizedBox(height: 24),
                _footerLinkSection('Feedback', 'Support', 'Status'),
                const SizedBox(height: 24),
                _footerLinkSection('Contact', 'Twitter', 'GitHub'),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _footerLinkSection(
                  'Terms of Service',
                  'Privacy Policy',
                  'Security',
                ),
                _footerLinkSection('Feedback', 'Support', 'Status'),
                _footerLinkSection('Contact', 'Twitter', 'GitHub'),
              ],
            ),
          const SizedBox(height: 32),
          const Text(
            '© 2025 Robin All rights reserved.',
            style: TextStyle(color: Colors.white54, fontSize: 12.0),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String text) {
    return HoverPopWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 14.0),
        ),
      ),
    );
  }

  Widget _footerLinkSection(String title, String link1, String link2) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoverPopWidget(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        HoverPopWidget(
          child: Text(
            link1,
            style: const TextStyle(color: Colors.white70, fontSize: 14.0),
          ),
        ),
        const SizedBox(height: 8),
        HoverPopWidget(
          child: Text(
            link2,
            style: const TextStyle(color: Colors.white70, fontSize: 14.0),
          ),
        ),
      ],
    );
  }
}
