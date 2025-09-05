import 'package:codemate/landing_page/landing_page.dart';
import 'package:flutter/material.dart';

class FeatureSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 120.0,
        vertical: 100,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextContent(),
                const SizedBox(height: 40),
                _buildImage(),
              ],
            )
          : Row(
              children: isReversed
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
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(bounds),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 36.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          description,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18.0,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        HoverScaleWidget(
          scale: 1.03,
          child: GlassButton(
            onPressed: () {},
            borderColor: Colors.blue,
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
        boxShadow: const [
          BoxShadow(
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imagePath,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
