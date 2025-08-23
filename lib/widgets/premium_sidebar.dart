import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/themes/colors.dart';

class PremiumSidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  PremiumSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

class PremiumSidebar extends StatefulWidget {
  final List<PremiumSidebarItem> items;
  final double collapsedWidth;
  final double expandedWidth;
  final double topPadding;

  const PremiumSidebar({
    super.key,
    required this.items,
    this.collapsedWidth = 60,
    this.expandedWidth = 220,
    this.topPadding = 16,
  });

  @override
  State<PremiumSidebar> createState() => _PremiumSidebarState();
}

class _PremiumSidebarState extends State<PremiumSidebar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final width = _hovered ? widget.expandedWidth : widget.collapsedWidth;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Column(
            children: [
              // App icon placeholder
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final selected = item.selected;
                    return InkWell(
                      onTap: item.onTap,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? AppColors.accent.withOpacity(0.12)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                selected
                                    ? AppColors.accent.withOpacity(0.25)
                                    : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color:
                                  selected ? AppColors.accent : Colors.white70,
                              size: 22,
                            ),
                            if (_hovered) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight:
                                        selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
