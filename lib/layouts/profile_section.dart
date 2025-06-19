import 'package:codemate/layouts/glass_icon_button.dart';
import 'package:flutter/material.dart';

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GlassIconButton(icon: Icons.notifications_rounded),
        const SizedBox(width: 12),
        GlassIconButton(icon: Icons.brightness_6_rounded),
        const SizedBox(width: 16),

        // Profile Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.lightBlue.withOpacity(0.5),
                Colors.blueAccent.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            // boxShadow: [
            //   BoxShadow(
            //     color: const Color(0xFF667EEA).withOpacity(0.3),
            //     blurRadius: 8,
            //     offset: const Offset(0, 4),
            //   ),
            // ],
          ),
          child: const Center(
            child: Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
