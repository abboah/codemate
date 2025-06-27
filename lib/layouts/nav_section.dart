import 'package:codemate/chatbot/chatbot.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/layouts/option2.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nav_provider.dart';

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

class NavItem extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isExpanded;
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
    required this.isExpanded,
  });

  @override
  ConsumerState<NavItem> createState() => _NavItemState();
}

class _NavItemState extends ConsumerState<NavItem> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final isSelected = selectedIndex == widget.index;
    final isExpanded = widget.isExpanded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(selectedNavIndexProvider.notifier).state = widget.index;
            if (widget.index == 0) {
              // Navigate to Dashboard
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return RobinDashboardMinimal();
                  },
                ),
              );
            } else if (widget.index == 3) {
              // Navigate to Chatbot
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const Chatbot();
                  },
                ),
              );
            } else if (widget.index == 8) {
              // Logout confirmation dialog
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Confirm Logout',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final authService = ref.read(authServiceProvider);
                            authService.logout();
                            Navigator.of(context).pop();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) {
                                  return LandingPage();
                                },
                              ),
                            );
                          },
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            }
          },
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
                  size: 25,
                ),
                const SizedBox(width: 14),
                isExpanded
                    ? Text(
                      widget.label,
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 15,
                      ),
                    )
                    : const SizedBox.shrink(),
                const Spacer(),
                // Uncomment the following lines if you want to add a trailing icon
                // Icon(
                //   isSelected ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                //   color: Colors.white.withOpacity(0.7),
                //   size: 16,
                // ),
                //      dense: true,
                // Text(
                //   widget.label,
                //   style: TextStyle(
                //     color:
                //         isSelected
                //             ? Colors.white
                //             : Colors.white.withOpacity(0.7),
                //     fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                //     fontSize: 15,
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
