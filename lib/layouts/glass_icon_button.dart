import 'package:flutter/material.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  const GlassIconButton({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
      ),
    );
  }
}
