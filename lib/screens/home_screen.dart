import 'dart:typed_data';
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
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const HomeScreen({super.key, required this.profile});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _buildButtonKey = GlobalKey();
  final GlobalKey _playgroundButtonKey = GlobalKey();
  final GlobalKey _learnButtonKey = GlobalKey();
  final GlobalKey _sidebarKey = GlobalKey();
  bool _showcaseStarted = false;

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
        'Keep up the great work,',
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

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_showcaseStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ShowCaseWidget.of(
              showcaseContext,
            ).startShowCase([_buildButtonKey, _learnButtonKey]);
          });
          _showcaseStarted = true;
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A0A0D),
                  Color(0xFF121216),
                  Color(0xFF1A1A20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Row(
              children: [
                PremiumSidebar(
                  items: [
                    PremiumSidebarItem(
                      icon: Icons.home,
                      label: 'Home',
                      onTap: () {},
                      selected: true,
                    ),
                    PremiumSidebarItem(
                      icon: Icons.play_arrow_rounded,
                      label: 'Playground',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PlaygroundPage(),
                          ),
                        );
                      },
                    ),
                    PremiumSidebarItem(
                      icon: Icons.construction_rounded,
                      label: 'Build',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BuildPage()),
                        );
                      },
                    ),
                    PremiumSidebarItem(
                      icon: Icons.school_rounded,
                      label: 'Learn',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LearnPage()),
                        );
                      },
                    ),
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
                              _buildTopBar(
                                context,
                                initials,
                                widget.profile.fullName,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 80,
                                  ), // Moves content up by adding bottom padding
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildGreeting(widget.profile.username),
                                      const SizedBox(height: 40),
                                      _buildActionButtons(
                                        context,
                                        projectsCount,
                                        coursesCount,
                                      ),
                                      const SizedBox(height: 28),
                                      Align(
                                        alignment: Alignment.center,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.3,
                                          ),
                                          child: _HomeInputBar(),
                                        ),
                                      ),
                                    ],
                                  ),
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
          ),
        );
      },
    );
  }

  Widget _buildGlowEffect(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Primary accent glow - top left
        Positioned(
          top: screenSize.height * 0.15,
          left: -150,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.25),
                  AppColors.accent.withOpacity(0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),
        // Secondary purple glow - top right
        Positioned(
          top: screenSize.height * 0.1,
          right: -200,
          child: Container(
            width: 600,
            height: 600,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7F5AF0).withOpacity(0.18),
                  const Color(0xFF9D4EDD).withOpacity(0.06),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Tertiary blue glow - bottom left
        Positioned(
          bottom: screenSize.height * 0.2,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.15),
                  const Color(0xFF1E40AF).withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Ambient center glow - very subtle
        Positioned(
          top: screenSize.height * 0.3,
          left: screenSize.width * 0.3,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.03), Colors.transparent],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        // Gradient overlay for depth
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.6),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, String initials, String fullName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 28,
            ),
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
          style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    int projectsCount,
    int coursesCount,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Showcase(
          key: _buildButtonKey,
          title: 'Build',
          titleTextAlign: TextAlign.center,
          descriptionTextAlign: TextAlign.center,
          description: 'Start a new project with AI assistance',
          child: _buildActionButton(
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
        ),
        const SizedBox(width: 30),
        Showcase(
          key: _learnButtonKey,
          title: 'Learn',
          titleTextAlign: TextAlign.center,
          descriptionTextAlign: TextAlign.center,
          description: 'Explore guided learning paths and courses',
          child: _buildActionButton(
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
  bool _uploading =
      false; // show 'Processing attachments…' while uploading on send
  OverlayEntry? _imageHoverOverlay;

  @override
  void dispose() {
    try {
      _imageHoverOverlay?.remove();
    } catch (_) {}
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md') || lower.endsWith('.markdown'))
      return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.json')) return 'application/json';
    return 'application/octet-stream';
  }

  Future<void> _pickFiles() async {
    // Match Playground: queue bytes locally; upload on send
    // Allowed extensions
    const allowed = {
      'pdf',
      'png',
      'jpg',
      'jpeg',
      'webp',
      'gif',
      'txt',
      'md',
      'markdown',
      'html',
      'htm',
      'xml',
    };

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowed.toList(),
    );
    if (result == null) return;
    // Enforce 3-file limit like Playground
    final remaining = 3 - _attachments.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can attach up to 3 files.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }
    int rejected = 0;
    for (final f in result.files.take(remaining)) {
      if (f.bytes == null) continue;
      final ext = (f.extension ?? f.name.split('.').last).toLowerCase();
      if (!allowed.contains(ext)) {
        rejected++;
        continue;
      }
      _attachments.add({
        'bytes': f.bytes!,
        'mime_type': _guessMime(f.name),
        'file_name': f.name,
      });
    }
    if (rejected > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Some files were rejected (unsupported type).',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
    setState(() {});
  }

  void _removeAttachmentAt(int index) {
    setState(() => _attachments.removeAt(index));
  }

  void _removeImageHoverOverlay() {
    try {
      _imageHoverOverlay?.remove();
    } catch (_) {}
    _imageHoverOverlay = null;
  }

  void _showImageHoverOverlayForPill(BuildContext pillContext, String url) {
    _removeImageHoverOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderObject = pillContext.findRenderObject();
    if (renderObject is! RenderBox) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screen = MediaQuery.of(context).size;

    const previewW = 220.0;
    const previewH = 160.0;
    double left = topLeft.dx;
    if (left + previewW > screen.width - 8) left = screen.width - 8 - previewW;
    if (left < 8) left = 8;
    double top = topLeft.dy - previewH - 8;
    if (top < 8) top = topLeft.dy + size.height + 8;

    _imageHoverOverlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            left: left,
            top: top,
            width: previewW,
            height: previewH,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: previewW,
                      height: previewH,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
    overlay.insert(_imageHoverOverlay!);
  }

  void _showImageHoverOverlayForPillBytes(
    BuildContext pillContext,
    List<int> bytes,
  ) {
    _removeImageHoverOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderObject = pillContext.findRenderObject();
    if (renderObject is! RenderBox) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screen = MediaQuery.of(context).size;

    const previewW = 220.0;
    const previewH = 160.0;
    double left = topLeft.dx;
    if (left + previewW > screen.width - 8) left = screen.width - 8 - previewW;
    if (left < 8) left = 8;
    double top = topLeft.dy - previewH - 8;
    if (top < 8) top = topLeft.dy + size.height + 8;

    _imageHoverOverlay = OverlayEntry(
      builder:
          (ctx) => Positioned(
            left: left,
            top: top,
            width: previewW,
            height: previewH,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      (bytes is List<int>)
                          ? Uint8List.fromList(bytes)
                          : (bytes as Uint8List),
                      width: previewW,
                      height: previewH,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
    overlay.insert(_imageHoverOverlay!);
  }

  void _showImageModalBytes(Uint8List bytes, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (ctx) => Dialog(
            backgroundColor: const Color(0xFF0F1420),
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 840),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showImageModal(String url, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder:
          (ctx) => Dialog(
            backgroundColor: const Color(0xFF0F1420),
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 840),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          ),
    );
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
    () async {
      setState(() => _sending = true);
      final client = Supabase.instance.client;
      final List<Map<String, dynamic>> out = [];

      final hasUploadables = _attachments.any(
        (a) => a['bytes'] is Uint8List || a['bytes'] is List<int>,
      );
      if (hasUploadables) setState(() => _uploading = true);

      // Already-uploaded items (rare in Home after this refactor)
      for (final a in _attachments.where(
        (a) => a.containsKey('bucket') && a.containsKey('path'),
      )) {
        final path = a['path'] as String;
        final signedUrl = await _createSignedUrl(client, path);
        final bucket = (a['bucket'] as String?) ?? 'user-uploads';
        out.add({
          'bucket': bucket,
          'path': path,
          'mime_type': a['mime_type'],
          'file_name': a['file_name'],
          if (signedUrl != null) 'signedUrl': signedUrl,
          if (signedUrl != null)
            'bucket_url':
                signedUrl, // backend will sanitize to real bucket path
          if (signedUrl != null) 'uri': signedUrl,
        });
      }

      // Items that only have a bucket_url
      for (final a in _attachments.where(
        (a) => !a.containsKey('path') && (a['bucket_url'] is String),
      )) {
        final bukUrl = (a['bucket_url'] as String?) ?? '';
        out.add({
          'bucket_url': bukUrl,
          'mime_type': a['mime_type'],
          'file_name': a['file_name'],
          if (bukUrl.isNotEmpty) 'uri': bukUrl,
          if (bukUrl.isNotEmpty) 'signedUrl': bukUrl,
        });
      }

      // Upload raw bytes now
      for (final a in _attachments.where(
        (a) => !(a.containsKey('bucket') && a.containsKey('path')),
      )) {
        final bytes = a['bytes'];
        final mime = (a['mime_type'] as String?) ?? 'application/octet-stream';
        final name = (a['file_name'] as String?) ?? 'file';
        if (bytes is Uint8List || bytes is List<int>) {
          try {
            final data =
                (bytes is Uint8List)
                    ? bytes
                    : Uint8List.fromList(bytes as List<int>);
            final folder = 'home/uploads';
            final path =
                '$folder/${DateTime.now().millisecondsSinceEpoch}_$name';
            await client.storage
                .from('user-uploads')
                .uploadBinary(
                  path,
                  data,
                  fileOptions: FileOptions(contentType: mime, upsert: true),
                );
            final signedUrl = await _createSignedUrl(client, path);
            const bucket = 'user-uploads';
            out.add({
              'bucket': bucket,
              'path': path,
              'mime_type': mime,
              'file_name': name,
              if (signedUrl != null) 'signedUrl': signedUrl,
              if (signedUrl != null)
                'bucket_url':
                    signedUrl, // backend will sanitize to real bucket path
              if (signedUrl != null) 'uri': signedUrl,
            });
          } catch (e) {
            // Skip adding the file if upload fails; surface a subtle toast.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to upload $name',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
        }
      }

      if (hasUploadables) setState(() => _uploading = false);

      final prov = ref.read(playgroundProvider);
      // Clear UI immediately
      _controller.clear();
      _attachments.clear();
      setState(() {});

      // Fire-and-forget: start sending so it appears when we land on Playground
      // Provider adds the user/ai temp messages immediately (optimistic).
      // Don't await to avoid blocking navigation.
      // ignore: unawaited_futures
      prov.send(text: text, attachments: out);
      _goToPlayground(context); // Navigate immediately as usual
      setState(() => _sending = false);
    }();
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
                  padding: const EdgeInsets.only(
                    bottom: 8.0,
                    left: 4,
                    right: 4,
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < _attachments.length; i++)
                        Builder(
                          builder: (pillCtx) {
                            final a = _attachments[i];
                            final name = a['file_name'] as String? ?? 'file';
                            final mime =
                                a['mime_type'] as String? ??
                                'application/octet-stream';
                            final isImage = mime.startsWith('image/');
                            final bytes = a['bytes'] as Uint8List?;
                            final signedUrl = a['signedUrl'] as String?;
                            final bucketUrl = a['bucket_url'] as String?;
                            final url =
                                (signedUrl != null && signedUrl.isNotEmpty)
                                    ? signedUrl
                                    : ((bucketUrl != null &&
                                            bucketUrl.isNotEmpty)
                                        ? bucketUrl
                                        : null);
                            final pill = Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isImage
                                        ? Icons.image_outlined
                                        : Icons.attach_file,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _removeAttachmentAt(i),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white60,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (isImage && bytes != null) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter:
                                    (_) => _showImageHoverOverlayForPillBytes(
                                      pillCtx,
                                      bytes,
                                    ),
                                onExit: (_) => _removeImageHoverOverlay(),
                                child: GestureDetector(
                                  onTap:
                                      () => _showImageModalBytes(bytes, name),
                                  child: pill,
                                ),
                              );
                            } else if (isImage && url != null) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter:
                                    (_) => _showImageHoverOverlayForPill(
                                      pillCtx,
                                      url,
                                    ),
                                onExit: (_) => _removeImageHoverOverlay(),
                                child: GestureDetector(
                                  onTap: () => _showImageModal(url, name),
                                  child: pill,
                                ),
                              );
                            } else {
                              return pill;
                            }
                          },
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
                onSubmitted:
                    (_) => (_sending || _uploading) ? null : _send(context),
              ),
              const SizedBox(height: 8),
              // Bottom layer: attach + send row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: (_sending || _uploading) ? null : _pickFiles,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed:
                        (_sending || _uploading) ? null : () => _send(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    child:
                        (_sending || _uploading)
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: MiniWave(size: 22),
                            )
                            : const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                            ),
                  ),
                ],
              ),
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Processing attachments…',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _createSignedUrl(SupabaseClient client, String path) async {
    try {
      final dynamic resp = await client.storage
          .from('user-uploads')
          .createSignedUrl(path, 60 * 60);
      if (resp is String) return resp;
      if (resp is Map) {
        final v1 = resp['signedUrl'];
        if (v1 is String) return v1;
        final v2 = resp['signed_url'];
        if (v2 is String) return v2;
        final v3 = resp['url'];
        if (v3 is String) return v3;
        final data = resp['data'];
        if (data is Map && data['signedUrl'] is String)
          return data['signedUrl'] as String;
      }
    } catch (_) {}
    return null;
  }
}
