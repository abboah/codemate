import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:codemate/components/custom_tooltip.dart';
import 'package:codemate/components/settings_profile_modal.dart';
import 'package:codemate/providers/courses_provider.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/themes/colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/providers/playground_provider.dart';
import 'package:codemate/widgets/premium_sidebar.dart';

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
      body: Row(
        children: [
          PremiumSidebar(
            items: [
              PremiumSidebarItem(icon: Icons.home, label: 'Home', onTap: () {} , selected: true),
              PremiumSidebarItem(icon: Icons.play_arrow_rounded, label: 'Playground', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaygroundPage()));
              }),
              PremiumSidebarItem(icon: Icons.construction_rounded, label: 'Build', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BuildPage()));
              }),
              PremiumSidebarItem(icon: Icons.school_rounded, label: 'Learn', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LearnPage()));
              }),
            ],
            topPadding: 20,
          ),
          Expanded(
            child: Stack(
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
                              const SizedBox(height: 40),
                              _buildActionButtons(context, projectsCount, coursesCount),
                              const SizedBox(height: 28),
                              Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                                  child: _HomeInputBar(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              AppColors.accent.withOpacity(0.3),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
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

class _HomeInputBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HomeInputBar> createState() => _HomeInputBarState();
}

class _HomeInputBarState extends ConsumerState<_HomeInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _attachments = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    for (final f in result.files) {
      if (f.bytes == null) continue;
      final b64 = base64Encode(f.bytes!);
      _attachments.add({
        'base64': b64,
        'mime_type': _guessMime(f.name),
        'file_name': f.name,
      });
    }
    setState(() {});
  }

  void _removeAttachmentAt(int index) {
    setState(() => _attachments.removeAt(index));
  }

  void _goToPlayground(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlaygroundPage()),
    );
  }

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    // Kick off the first playground message immediately so it appears when we land there
    final prov = ref.read(playgroundProvider);
    final payload = List<Map<String, dynamic>>.from(_attachments);
    prov.send(text: text, attachments: payload);
    // Navigate to Playground to view the conversation
    _goToPlayground(context);
    // Reset local state
    _controller.clear();
    _attachments.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
  return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top layer: input area (and attachments chips)
              if (_attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < _attachments.length; i++)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                (_attachments[i]['file_name'] as String?) ?? 'file',
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeAttachmentAt(i),
                                child: const Icon(Icons.close, color: Colors.white60, size: 14),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 6,
                minLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask or start building…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sending ? null : _send(context),
              ),
              const SizedBox(height: 8),
              // Bottom layer: attach + send row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                    ),
                  ]),
                  ElevatedButton(
                    onPressed: _sending ? null : () => _send(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: _sending
                        ? const SizedBox(width: 22, height: 22, child: MiniWave(size: 22))
                        : const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
