import 'package:flutter/material.dart';

class NavSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const NavSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
  });

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  @override
  Widget build(BuildContext context) {
    int selectedIndex = 0;
    final isSelected = selectedIndex == widget.index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => selectedIndex = widget.index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border:
                  isSelected
                      ? Border.all(color: Colors.white.withOpacity(0.3))
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
