import 'package:codemate/landing_page/landing_page.dart';
import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(),
        ),
        Container(
          color: const Color(0xFF000000),
          padding: EdgeInsets.symmetric(
            horizontal:
                isMobile
                    ? 24.0
                    : isTablet
                    ? 60.0
                    : 120.0,
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
                      _buildFooterLinks(isMobile),
                      const SizedBox(height: 40),
                      _buildSocialLinks(),
                    ],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildLogoSection()),
                      Expanded(flex: 2, child: _buildFooterLinks(isMobile)),
                      Expanded(child: _buildSocialLinks()),
                    ],
                  ),
              const SizedBox(height: 60),
              const Divider(color: Color(0xFF333333)),
              const SizedBox(height: 30),
              isMobile
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '© 2025 Robin. All rights reserved.',
                        style: TextStyle(color: Color(0xFFAAAAAA)),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          _footerLink('Privacy Policy'),
                          _footerLink('Terms of Service'),
                          _footerLink('Cookie Policy'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _backToTopButton(context),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '© 2025 Robin. All rights reserved.',
                        style: TextStyle(color: Color(0xFFAAAAAA)),
                      ),
                      Row(
                        children: [
                          _footerLink('Privacy Policy'),
                          const SizedBox(width: 24),
                          _footerLink('Terms of Service'),
                          const SizedBox(width: 24),
                          _footerLink('Cookie Policy'),
                          const SizedBox(width: 40),
                          _backToTopButton(context),
                        ],
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.flutter_dash, color: Colors.white, size: 28),
            SizedBox(width: 8),
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

  static Widget _buildFooterLinks(bool isMobile) {
    final links = {
      'Product': ['Features', 'Pricing', 'Integrations', 'Roadmap'],
      'Resources': ['Documentation', 'Tutorials', 'Blog', 'Community'],
      'Company': ['About', 'Careers', 'Contact', 'Press'],
    };

    return Wrap(
      spacing: isMobile ? 20 : 40,
      runSpacing: 30,
      children:
          links.entries.map((entry) {
            return SizedBox(
              width: isMobile ? 140 : 180,
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
                  ...entry.value.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HoverScaleWidget(
                        scale: 1.05,
                        child: Text(
                          item,
                          style: const TextStyle(color: Color(0xFFAAAAAA)),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          }).toList(),
    );
  }

  static Widget _buildSocialLinks() {
    final socialIcons = [Icons.facebook, Icons.reddit, Icons.discord];

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

  static Widget _footerLink(String text) {
    return HoverScaleWidget(
      scale: 1.05,
      child: Text(text, style: const TextStyle(color: Color(0xFFAAAAAA))),
    );
  }

  static Widget _backToTopButton(BuildContext context) {
    return HoverScaleWidget(
      scale: 1.1,
      child: TextButton.icon(
        onPressed: () {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        icon: const Icon(Icons.arrow_upward, color: Colors.white),
        label: const Text('Back to Top', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
