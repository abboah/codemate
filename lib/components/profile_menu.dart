import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileMenuModal extends StatelessWidget {
  const ProfileMenuModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMenuItem(context, Icons.person_outline, 'Account'),
                _buildMenuItem(context, Icons.settings_outlined, 'Settings'),
                const Divider(color: Colors.white24, height: 1),
                _buildMenuItem(context, Icons.logout_rounded, 'Logout', isDestructive: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Implement navigation/action
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.redAccent : Colors.white.withOpacity(0.8),
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: isDestructive ? Colors.redAccent : Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
