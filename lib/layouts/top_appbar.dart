import 'dart:ui';

import 'package:codemate/layouts/glass_search_bar.dart';
import 'package:codemate/layouts/profile_section.dart';
import 'package:flutter/material.dart';

class TopAppbar extends StatelessWidget {
  final bool isDesktop;
  const TopAppbar({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 40,
                  height: 40,
                  // decoration: BoxDecoration(
                  //   gradient: const LinearGradient(
                  //     colors: [Colors.white, Colors.white],
                  //   ),
                  //   borderRadius: BorderRadius.circular(12),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: const Color(0xFF667EEA).withOpacity(0.3),
                  //     blurRadius: 8,
                  //     offset: const Offset(0, 4),
                  //   ),
                  // ],
                  // ),
                  child: const Icon(
                    Icons.flutter_dash,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                // const SizedBox(width: 16),
                const Text(
                  'Robin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),

                const Spacer(),

                // Search
                if (isDesktop) ...[GlassSearchBar(), const SizedBox(width: 16)],

                // Profile & Actions
                ProfileSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
