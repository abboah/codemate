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
        return Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: itemWidth * widget.selectedIndex,
                top: 0,
                bottom: 0,
                child: Container(
                  width: itemWidth,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF667eea),
                        const Color(0xFF764ba2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(widget.labels.length, (index) {
                  final isSelected = index == widget.selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onToggle(index),
                      behavior: HitTestBehavior.translucent,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 48,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.poppins(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected 
                                  ? Colors.white 
                                  : Colors.white.withOpacity(0.7),
                              fontSize: isSelected ? 14 : 13,
                            ),
                            child: Text(
                              widget.labels[index],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
