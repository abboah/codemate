import 'dart:ui';

import 'package:codemate/landing_page/landing_page.dart';
import 'package:flutter/material.dart';

class PricingSection extends StatelessWidget {
  const PricingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      // color: const Color(0xFF0A0A0F),
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24.0 : 120.0,
        vertical: 100,
      ),
      child: Column(
        children: [
          const Text(
            'SIMPLE, TRANSPARENT PRICING',
            style: TextStyle(
              //  color: Color(0xFF6C5DD3),
              color: Colors.blue,
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
            style: TextStyle(color: Colors.white, fontSize: 18.0),
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
                    isFeatured: true,
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
                      isFeatured: true,
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
                borderColor: Colors.blue,
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
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: isFeatured ? Colors.transparent : Colors.transparent,

                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  // color: isFeatured ? Colors.blue : Colors.blue,
                  width: 2,
                ),
                //  boxShadow: [
                // if (isFeatured)
                //   BoxShadow(
                //     // color: const Color(0xFF6C5DD3).withOpacity(0.3),
                //     blurRadius: 20,
                //     spreadRadius: 5,
                //   ),
                /// ],
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
                          colors: [Colors.lightBlue, Colors.blueAccent],
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
                                color: Colors.blue,
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
                              colors: [Colors.lightBlue, Colors.blueAccent],
                            )
                            : null,
                    borderColor: isFeatured ? Colors.transparent : Colors.blue,
                    child: Text(
                      isFeatured ? 'Get Started' : 'Try Free',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isFeatured ? Colors.white : Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
