import 'dart:ui';
import 'package:codemate/layouts/nav_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sidebar_provider.dart';

class DesktopSidebar extends ConsumerStatefulWidget {
  const DesktopSidebar({super.key});

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(sidebarExpandedProvider);
    double sidebarWidth = isExpanded ? 280 : 100;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      margin: const EdgeInsets.only(left: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Toggle button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(
                        isExpanded
                            ? Icons.view_sidebar_rounded
                            : Icons.view_sidebar_outlined,
                        size: 25,
                      ),
                      color: Colors.white.withOpacity(0.7),
                      onPressed: () {
                        ref.read(sidebarExpandedProvider.notifier).state =
                            !isExpanded;
                      },
                    ),
                  ),
                ),

                // Navigation Sections
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      NavSection(
                        title: 'MAIN',
                        items: [
                          NavItem(
                            icon: Icons.dashboard_rounded,
                            label: 'Dashboard',
                            index: 0,
                            isExpanded: isExpanded,
                          ),
                          NavItem(
                            icon: Icons.folder_rounded,
                            label: 'Projects',
                            index: 1,
                            isExpanded: isExpanded,
                          ),
                          NavItem(
                            icon: Icons.school_rounded,
                            label: 'Learning Paths',
                            index: 2,
                            isExpanded: isExpanded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      NavSection(
                        title: 'TOOLS',
                        items: [
                          NavItem(
                            icon: Icons.chat_bubble_rounded,
                            label: 'AI Assistant',
                            index: 3,
                            isExpanded: isExpanded,
                          ),
                          NavItem(
                            icon: Icons.code_rounded,
                            label: 'Code Editor',
                            index: 4,
                            isExpanded: isExpanded,
                          ),
                          NavItem(
                            icon: Icons.quiz_rounded,
                            label: 'Assessments',
                            index: 5,
                            isExpanded: isExpanded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      NavSection(
                        title: 'SOCIAL',
                        items: [
                          NavItem(
                            icon: Icons.leaderboard_rounded,
                            label: 'Leaderboard',
                            index: 6,
                            isExpanded: isExpanded,
                          ),
                          NavItem(
                            icon: Icons.people_rounded,
                            label: 'Community',
                            index: 7,
                            isExpanded: isExpanded,
                          ),
                        ],
                      ),
                    ],
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
