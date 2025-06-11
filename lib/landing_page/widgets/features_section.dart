import 'package:codemate/landing_page/landing_page.dart';
import 'package:flutter/material.dart';

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
      //  color: const Color(0xFF0A0A0F),
      color: Colors.black,

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
                //  colors: [Color(0xFF6C5DD3), Color(0xFF1E90FF)],
                //  colors: [Colors.lightBlue, Colors.blueAccent],
                colors: [Colors.white, Colors.white],
              ).createShader(bounds),
          child: Text(
            widget.title,
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
          widget.description,
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
            //  borderColor: const Color(0xFF6C5DD3),
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
        boxShadow: [
          BoxShadow(
            //    color: const Color(0xFF6C5DD3).withOpacity(0.2),
            //     color: Colors.blue,
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
