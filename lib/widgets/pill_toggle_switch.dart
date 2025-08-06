import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PillToggleSwitch extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onToggle;
  final List<String> labels;

  const PillToggleSwitch({
    super.key,
    required this.selectedIndex,
    required this.onToggle,
    required this.labels,
  });

  @override
  State<PillToggleSwitch> createState() => _PillToggleSwitchState();
}

class _PillToggleSwitchState extends State<PillToggleSwitch> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / widget.labels.length;
        return ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: itemWidth * widget.selectedIndex,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: itemWidth,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(widget.labels.length, (index) {
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onToggle(index),
                          behavior: HitTestBehavior.translucent,
                          child: Center(
                            child: Text(
                              widget.labels[index],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
