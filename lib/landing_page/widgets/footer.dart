import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// Main Legal Policies Manager
class LegalPolicies {
  static void showPrivacyPolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Privacy Policy',
      content: _getPrivacyPolicyContent(),
    );
  }

  static void showTermsOfService(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Terms of Service',
      content: _getTermsOfServiceContent(),
    );
  }

  static void showCookiePolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Cookie Policy',
      content: _getCookiePolicyContent(),
    );
  }

  static void _showLegalDialog(BuildContext context, {
    required String title,
    required Widget content,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: LegalPolicyDialog(title: title, content: content),
        );
      },
    );
  }
}

// Custom Dialog Widget
class LegalPolicyDialog extends StatelessWidget {
  final String title;
  final Widget content;

  const LegalPolicyDialog({
    Key? key,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 768;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: isMobile ? screenSize.width * 0.95 : 800,
        maxHeight: screenSize.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111118),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF333333))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Color(0xFF333333)),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: content,
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF333333))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Last updated: ${_getFormattedDate()}',
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// Privacy Policy Content
Widget _getPrivacyPolicyContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSection(
        'Information We Collect',
        [
          'We collect information you provide directly to us, such as when you create an account, use our services, or contact us.',
          'We automatically collect certain information about your device and usage of our service, including IP address, browser type, operating system, and usage patterns.',
          'We may collect information from third-party services you connect to Robin, such as GitHub or other development platforms.',
        ],
      ),
      _buildSection(
        'How We Use Your Information',
        [
          'To provide, maintain, and improve our services',
          'To process transactions and send related information',
          'To send technical notices, updates, security alerts, and support messages',
          'To respond to your comments, questions, and customer service requests',
          'To communicate with you about products, services, and events',
          'To monitor and analyze trends, usage, and activities',
        ],
      ),
      _buildSection(
        'Information Sharing',
        [
          'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy.',
          'We may share your information with service providers who assist us in operating our website and conducting our business.',
          'We may disclose your information if required by law or to protect our rights and safety.',
        ],
      ),
      _buildSection(
        'Data Security',
        [
          'We implement appropriate technical and organizational security measures to protect your personal information.',
          'However, no method of transmission over the internet or electronic storage is 100% secure.',
          'We regularly review and update our security practices to protect your data.',
        ],
      ),
      _buildSection(
        'Your Rights',
        [
          'You have the right to access, update, or delete your personal information.',
          'You can opt out of marketing communications at any time.',
          'You may request a copy of your data or request that we delete your account.',
          'For EU residents: You have additional rights under GDPR, including data portability and the right to object to processing.',
        ],
      ),
      _buildSection(
        'Contact Information',
        [
          'If you have any questions about this Privacy Policy, please contact us at:',
          'Email: privacy@robin.dev',
          'Address: [Your Company Address]',
        ],
      ),
    ],
  );
}

// Terms of Service Content
Widget _getTermsOfServiceContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSection(
        'Acceptance of Terms',
        [
          'By accessing and using Robin, you accept and agree to be bound by the terms and provision of this agreement.',
          'If you do not agree to abide by the above, please do not use this service.',
        ],
      ),
      _buildSection(
        'Description of Service',
        [
          'Robin is an AI-powered developer tool platform that provides coding assistance, project building capabilities, and learning resources.',
          'We reserve the right to modify, suspend, or discontinue any aspect of the service at any time.',
        ],
      ),
      _buildSection(
        'User Accounts',
        [
          'You are responsible for maintaining the confidentiality of your account credentials.',
          'You agree to accept responsibility for all activities that occur under your account.',
          'You must notify us immediately of any unauthorized use of your account.',
          'You must be at least 13 years old to create an account.',
        ],
      ),
      _buildSection(
        'Acceptable Use',
        [
          'You agree not to use the service for any unlawful purpose or in any way that could damage, disable, or impair the service.',
          'You may not attempt to gain unauthorized access to any portion of the service.',
          'You agree not to use the service to create, generate, or distribute malicious code or content.',
          'Harassment, abuse, or discrimination of any kind is prohibited.',
        ],
      ),
      _buildSection(
        'Intellectual Property',
        [
          'The service and its original content, features, and functionality are owned by Robin and are protected by copyright, trademark, and other laws.',
          'You retain ownership of any code or content you create using our service.',
          'By using our service, you grant us a license to use, modify, and display your content as necessary to provide the service.',
        ],
      ),
      _buildSection(
        'Limitation of Liability',
        [
          'Robin shall not be liable for any indirect, incidental, special, consequential, or punitive damages.',
          'Our total liability shall not exceed the amount paid by you for the service in the past 12 months.',
          'Some jurisdictions do not allow the exclusion of certain warranties or limitation of liability.',
        ],
      ),
      _buildSection(
        'Termination',
        [
          'We may terminate or suspend your account immediately, without prior notice, for conduct that we believe violates these Terms.',
          'You may terminate your account at any time by contacting us.',
          'Upon termination, your right to use the service will cease immediately.',
        ],
      ),
      _buildSection(
        'Changes to Terms',
        [
          'We reserve the right to modify these terms at any time.',
          'We will notify users of significant changes via email or through the service.',
          'Continued use of the service after changes constitutes acceptance of the new terms.',
        ],
      ),
    ],
  );
}

// Cookie Policy Content
Widget _getCookiePolicyContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSection(
        'What Are Cookies',
        [
          'Cookies are small text files that are placed on your computer or mobile device when you visit a website.',
          'They are widely used to make websites work more efficiently and provide information to website owners.',
        ],
      ),
      _buildSection(
        'How We Use Cookies',
        [
          'Essential Cookies: These cookies are necessary for the website to function properly and cannot be switched off.',
          'Performance Cookies: These cookies collect information about how you use our website to help us improve it.',
          'Functionality Cookies: These cookies allow us to remember choices you make and provide enhanced features.',
          'Analytics Cookies: We use these to understand how visitors interact with our website.',
        ],
      ),
      _buildSection(
        'Types of Cookies We Use',
        [
          'Session Cookies: These are temporary cookies that expire when you close your browser.',
          'Persistent Cookies: These remain on your device for a set period or until you delete them.',
          'First-party Cookies: Set by our website directly.',
          'Third-party Cookies: Set by external services we use, such as analytics providers.',
        ],
      ),
      _buildSection(
        'Third-Party Cookies',
        [
          'We may use third-party services that place cookies on your device:',
          '• Google Analytics: For website analytics and performance measurement',
          '• Authentication services: For secure login functionality',
          '• CDN services: For content delivery optimization',
        ],
      ),
      _buildSection(
        'Managing Cookies',
        [
          'You can control and manage cookies in various ways:',
          '• Browser settings: Most browsers allow you to manage cookie preferences',
          '• Opt-out tools: Many advertising networks provide opt-out mechanisms',
          '• Privacy settings: Adjust your privacy preferences in your account settings',
        ],
      ),
      _buildSection(
        'Cookie Consent',
        [
          'By continuing to use our website, you consent to our use of cookies as described in this policy.',
          'You can withdraw your consent at any time by adjusting your browser settings or contacting us.',
          'Disabling cookies may affect the functionality of our website.',
        ],
      ),
      _buildSection(
        'Updates to This Policy',
        [
          'We may update this Cookie Policy from time to time to reflect changes in our practices or for other operational, legal, or regulatory reasons.',
          'We will notify you of any material changes by posting the new policy on our website.',
        ],
      ),
    ],
  );
}

// Helper method to build sections
Widget _buildSection(String title, List<String> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 24),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          item.startsWith('•') ? item : '• $item',
          style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      )).toList(),
    ],
  );
}

// Updated Footer Widget with Dialog Integration
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
            horizontal: isMobile ? 24.0 : isTablet ? 60.0 : 120.0,
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
                     //   _buildFooterLinks(isMobile),
                        const SizedBox(height: 40),
                        _buildSocialLinks(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLogoSection(),
                   //     Expanded(flex: 2, child: _buildFooterLinks(isMobile)),
                   
                            Row( mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _footerLink(context, 'Privacy Policy', () => 
                                  LegalPolicies.showPrivacyPolicy(context)),
                                const SizedBox(width: 24),
                                _footerLink(context, 'Terms of Service', () => 
                                  LegalPolicies.showTermsOfService(context)),
                                const SizedBox(width: 24),
                                _footerLink(context, 'Cookie Policy', () => 
                                  LegalPolicies.showCookiePolicy(context)),
                                const SizedBox(width: 40),
                              ],
                            ),
                        //    _backToTopButton(context),
                      
                        _buildSocialLinks(),
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
                            _footerLink(context, 'Privacy Policy', () => 
                              LegalPolicies.showPrivacyPolicy(context)),
                            _footerLink(context, 'Terms of Service', () => 
                              LegalPolicies.showTermsOfService(context)),
                            _footerLink(context, 'Cookie Policy', () => 
                              LegalPolicies.showCookiePolicy(context)),
                          ],
                        ),
                        const SizedBox(height: 20),
                   //     _backToTopButton(context),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '© 2025 Robin. All rights reserved.',
                          style: TextStyle(color: Color(0xFFAAAAAA)),
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
      children: links.entries.map((entry) {
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
          children: socialIcons.map((icon) {
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

  static Widget _footerLink(BuildContext context, String text, VoidCallback onTap) {
    return HoverScaleWidget(
      scale: 1.05,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 16, fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFFAAAAAA),
          ),
        ),
      ),
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

// HoverScaleWidget (assuming it's not defined elsewhere)
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