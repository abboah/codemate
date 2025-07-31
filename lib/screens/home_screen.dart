import 'dart:math';
import 'dart:ui';
import 'package:codemate/components/custom_tooltip.dart';
import 'package:codemate/components/settings_profile_modal.dart';
import 'package:codemate/providers/courses_provider.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/screens/chat_page.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial counts when the screen loads
    Future.microtask(() {
      ref.read(projectsProvider).fetchProjects();
      ref.read(coursesProvider).fetchEnrolledCoursesCount();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    const greetings = {
      'morning': ['Good morning,', 'Rise and shine,', 'A new day awaits,'],
      'afternoon': [
        'Good afternoon,',
        "Hope you're having a great day,",
        'Keep up the great work,'
      ],
      'evening': ['Good evening,', 'Time to wind down,', 'The night is young,'],
    };
    final key = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');
    return greetings[key]![Random().nextInt(greetings[key]!.length)];
  }

  String _getSecondaryGreeting() {
    const options = [
      "What will you work on today?",
      "Ready to build something amazing?",
      "Let's make some magic happen.",
      "Time to dive into some code.",
    ];
    return options[Random().nextInt(options.length)];
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '??';
    List<String> names = fullName.split(" ");
    String initials = "";
    if (names.isNotEmpty) {
      initials += names[0][0];
    }
    if (names.length > 1) {
      initials += names[names.length - 1][0];
    }
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(widget.profile.fullName);
    final projectsCount = ref.watch(projectsProvider).projects.length;
    final coursesCount = ref.watch(coursesProvider).enrolledCoursesCount;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildGlowEffect(context),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildTopBar(context, initials, widget.profile.fullName),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGreeting(widget.profile.username),
                        const SizedBox(height: 60),
                        _buildActionButtons(context, projectsCount, coursesCount),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowEffect(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.1,
      left: -100,
      child: Container(
        width: 400,
        height: 400,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.blueAccent.withOpacity(0.3),
              Colors.black.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String initials, String fullName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded,
                color: Colors.white.withOpacity(0.8), size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
          CustomTooltip(
            message: fullName,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const SettingsProfileModal(),
                );
              },
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.1),
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting(String name) {
    return Column(
      children: [
        Text(
          _getGreeting(),
          style: GoogleFonts.poppins(
            fontSize: 42,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          '$name!',
          style: GoogleFonts.poppins(
            fontSize: 42,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _getSecondaryGreeting(),
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, int projectsCount, int coursesCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          context,
          icon: Icons.construction_rounded,
          label: 'Build',
          tooltip: 'Start a new project with AI assistance',
          badgeCount: projectsCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BuildPage()),
            );
          },
        ),
        const SizedBox(width: 30),
        _buildActionButton(
          context,
          icon: Icons.school_rounded,
          label: 'Learn',
          tooltip: 'Explore guided learning paths and courses',
          badgeCount: coursesCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LearnPage()),
            );
          },
        ),
        const SizedBox(width: 30),
        _buildActionButton(
          context,
          icon: Icons.chat_bubble_rounded,
          label: 'Chat',
          tooltip: 'Ask questions or brainstorm with the AI assistant',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return CustomTooltip(
      message: tooltip,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 56),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent,
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
