import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const CustomTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(seconds: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
      
    );
  }
}
