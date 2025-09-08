import 'dart:ui';

import 'package:codemate/auth/login_page.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:flutter/material.dart';

class NavBarDelegate extends SliverPersistentHeaderDelegate {
  const NavBarDelegate();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          if (shrinkOffset > 0)
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
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
  bool shouldRebuild(covariant NavBarDelegate oldDelegate) => false;
}

class NavBar extends StatefulWidget {
  final double transparency;

  const NavBar({Key? key, this.transparency = 0}) : super(key: key);

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _mobileMenuController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<NavItem> _navItems = [
    // NavItem('Features', Icons.star_outline),
    // NavItem('Solutions', Icons.lightbulb_outline),
    // NavItem('Resources', Icons.library_books_outlined),
    // NavItem('Pricing', Icons.attach_money_outlined),
  ];

  int _hoveredIndex = -1;
  bool _isMobileMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _mobileMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _mobileMenuController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _mobileMenuController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _mobileMenuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16.0 : (isTablet ? 32.0 : 48.0),
          vertical: 16.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLogo(),
            if (isMobile) _buildMobileMenuButton() else _buildDesktopNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return HoverScaleWidget(
      scale: 1.05,
      child: GestureDetector(
        onTap: () {
          // Navigate to home
        },
        child: Row(
          children: [
            const Icon(Icons.flutter_dash, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            const Text(
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
    );
  }

  Widget _buildMobileMenuButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: IconButton(
        icon: AnimatedRotation(
          turns: _isMobileMenuOpen ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(
            _isMobileMenuOpen ? Icons.close : Icons.menu,
            color: Colors.white,
            size: 28,
          ),
        ),
        onPressed: _toggleMobileMenu,
      ),
    );
  }

  Widget _buildDesktopNav() {
    return Row(
      children: [
        ...List.generate(_navItems.length, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildNavItem(index),
          );
        }),
        const SizedBox(width: 32),
        _buildCTAButton(),
      ],
    );
  }

  Widget _buildNavItem(int index) {
    final isHovered = _hoveredIndex == index;

    return InkWell(
      onHover: (hovering) {
        setState(() {
          _hoveredIndex = hovering ? index : -1;
        });
      },
      onTap: () {
        // Handle navigation
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              isHovered
                  ? Border.all(color: Colors.white.withOpacity(0.2))
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _navItems[index].icon,
                color: isHovered ? Colors.blue : Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _navItems[index].title,
              style: TextStyle(
                color: isHovered ? Colors.white : Colors.white,
                fontSize: 16,
                fontWeight: isHovered ? FontWeight.w600 : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTAButton() {
    return HoverScaleWidget(
      scale: 1.05,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.lightBlue, Colors.blueAccent],
            ),
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.rocket_launch_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleMobileMenu() {
    setState(() {
      _isMobileMenuOpen = !_isMobileMenuOpen;
    });

    if (_isMobileMenuOpen) {
      _mobileMenuController.forward();
      _showEnhancedMobileMenu();
    } else {
      _mobileMenuController.reverse();
    }
  }

  void _showEnhancedMobileMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Mobile Menu',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isVerySmall = screenWidth < 320;

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      width: screenWidth * 0.9,
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Menu',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() => _isMobileMenuOpen = false);
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Navigation Items
                            ..._navItems.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;

                              return AnimatedContainer(
                                duration: Duration(
                                  milliseconds: 200 + (index * 100),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isVerySmall ? 14 : 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white54,
                                    size: 14,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() => _isMobileMenuOpen = false);
                                    // Navigate if needed
                                  },
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 24),

                            // CTA Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LoginPage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ).copyWith(
                                  backgroundColor:
                                      MaterialStateProperty.resolveWith(
                                        (_) => Colors.transparent,
                                      ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.lightBlue,
                                        Colors.blueAccent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.rocket_launch_outlined,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Get Started',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ).then((_) {
      setState(() => _isMobileMenuOpen = false);
    });
  }
}

class NavItem {
  final String title;
  final IconData icon;

  NavItem(this.title, this.icon);
}

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
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
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
