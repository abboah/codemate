import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: const [
            NavBar(),
            HeroSection(),
            FeatureSection(
              title: "AI-Powered Code Assistance",
              description:
                  "Get intelligent suggestions as you code, with context-aware completions that learn your style.",
              isReversed: false,
            ),
            FeatureSection(
              title: "Interactive Learning",
              description:
                  "Master new concepts through hands-on coding exercises with real-time feedback.",
              isReversed: true,
            ),
            FeatureSection(
              title: "Seamless Integration",
              description:
                  "Works with your existing workflow and favorite tools without disruption.",
              isReversed: false,
            ),
            TestimonialsSection(),
            Footer(),
          ],
        ),
      ),
    );
  }
}

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: color.surface,
        border: Border(
          bottom: BorderSide(color: Colors.blueGrey.shade900, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Logo(),
          if (!isMobile)
            Row(
              children: [
                _NavItem("Features"),
                _NavItem("Pricing"),
                _NavItem("Docs"),
                _NavItem("Blog"),
                const SizedBox(width: 16),
                _OutlineButton("Sign In"),
                const SizedBox(width: 12),
                _FilledButton("Get Started"),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String text;

  const _NavItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: () {},
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String text;

  const _OutlineButton(this.text);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.blue.shade400, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final String text;

  const _FilledButton(this.text);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.code, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        const Text(
          'Robin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 64,
        vertical: 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade900.withOpacity(0.2), Colors.black],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Elevate Your Development Workflow',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            constraints: BoxConstraints(maxWidth: isMobile ? 400 : 600),
            child: Text(
              'Robin combines intelligent code assistance with interactive learning to help you write better code faster.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: isMobile ? 16 : 18,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          _FilledButton("Start Coding for Free"),
          const SizedBox(height: 60),
          Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 800,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade800, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade800.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/code_editor_demo.png', // Replace with your image
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureSection extends StatelessWidget {
  final String title;
  final String description;
  final bool isReversed;

  const FeatureSection({
    super.key,
    required this.title,
    required this.description,
    required this.isReversed,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 64,
        vertical: 80,
      ),
      color: Colors.grey.shade900.withOpacity(0.5),
      child:
          isMobile
              ? Column(
                children: [
                  _buildImage(),
                  const SizedBox(height: 40),
                  _buildText(),
                ],
              )
              : Row(
                children:
                    isReversed
                        ? [
                          Expanded(child: _buildImage()),
                          const SizedBox(width: 60),
                          Expanded(child: _buildText()),
                        ]
                        : [
                          Expanded(child: _buildText()),
                          const SizedBox(width: 60),
                          Expanded(child: _buildImage()),
                        ],
              ),
    );
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        _OutlineButton("Learn More"),
      ],
    );
  }

  Widget _buildImage() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blueGrey.shade900,
        border: Border.all(color: Colors.blueGrey.shade800, width: 1),
      ),
      child: const Center(
        child: Icon(Icons.terminal, color: Colors.blue, size: 80),
      ),
    );
  }
}

class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 64,
        vertical: 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.blue.shade900.withOpacity(0.2)],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Trusted by Developers Worldwide',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 60),
          isMobile
              ? Column(
                children: [
                  _buildTestimonial(
                    name: "Alex Johnson",
                    role: "Senior Engineer at TechCorp",
                    quote: "Robin has transformed how our team writes code.",
                  ),
                  const SizedBox(height: 40),
                  _buildTestimonial(
                    name: "Sarah Chen",
                    role: "Flutter Developer",
                    quote: "The AI suggestions save me hours every week.",
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: _buildTestimonial(
                      name: "Alex Johnson",
                      role: "Senior Engineer at TechCorp",
                      quote: "Robin has transformed how our team writes code.",
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _buildTestimonial(
                      name: "Sarah Chen",
                      role: "Flutter Developer",
                      quote: "The AI suggestions save me hours every week.",
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildTestimonial({
    required String name,
    required String role,
    required String quote,
  }) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade800, width: 1),
      ),
      child: Column(
        children: [
          Text(
            '"$quote"',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade800,
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 64,
        vertical: 60,
      ),
      color: Colors.black,
      child: Column(
        children: [
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Logo(),
                  const SizedBox(height: 40),
                  _FooterColumn(
                    title: "Product",
                    items: const ["Features", "Pricing", "Integrations"],
                  ),
                  const SizedBox(height: 30),
                  _FooterColumn(
                    title: "Resources",
                    items: const ["Documentation", "Tutorials", "Blog"],
                  ),
                  const SizedBox(height: 30),
                  _FooterColumn(
                    title: "Company",
                    items: const ["About", "Careers", "Contact"],
                  ),
                ],
              )
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Logo()),
                  _FooterColumn(
                    title: "Product",
                    items: const ["Features", "Pricing", "Integrations"],
                  ),
                  _FooterColumn(
                    title: "Resources",
                    items: const ["Documentation", "Tutorials", "Blog"],
                  ),
                  _FooterColumn(
                    title: "Company",
                    items: const ["About", "Careers", "Contact"],
                  ),
                ],
              ),
          const SizedBox(height: 60),
          Divider(color: Colors.blueGrey.shade800, thickness: 1),
          const SizedBox(height: 30),
          Text(
            "© 2023 Robin. All rights reserved.",
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;

  const _FooterColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 20),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              item,
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }
}
