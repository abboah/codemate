import 'dart:ui';
import 'dart:convert';
import 'dart:typed_data';
import 'package:codemate/themes/colors.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:codemate/providers/playground_provider.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:codemate/widgets/playground_code_block.dart';
import 'package:codemate/widgets/scroll_to_bottom_button.dart';
import 'package:codemate/widgets/tool_event_previews.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaygroundPage extends ConsumerStatefulWidget {
  const PlaygroundPage({super.key});

  @override
  ConsumerState<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends ConsumerState<PlaygroundPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _attachments = [];
  bool _uploading = false; // show 'Processing attachments…' while uploading on send
  int _artifactPreviewIndex = 0;
  // Composer image hover preview overlay
  OverlayEntry? _imageHoverOverlay;
  // Scroll controller for conversation and scroll-to-bottom button
  final ScrollController _conversationScrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    // Preload chats so the sidebar history shows up immediately on Playground
    Future.microtask(() {
      try { ref.read(playgroundProvider).fetchChats(); } catch (_) {}
    });
    
    // Add scroll listener for scroll-to-bottom button
    _conversationScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Ensure any hover overlay is removed
    try {
      _imageHoverOverlay?.remove();
    } catch (_) {}
    _controller.dispose();
    _focusNode.dispose();
    _conversationScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final isAtBottom = _conversationScrollController.offset >= 
        _conversationScrollController.position.maxScrollExtent - 100;
    
    // Show button when not at bottom and has some content to scroll
    final shouldShow = !isAtBottom && _conversationScrollController.position.maxScrollExtent > 200;
    
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }
  }

  void _scrollToBottom() {
    _conversationScrollController.animateTo(
      _conversationScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  static const Set<String> _allowedExts = {
    'png','jpg','jpeg','webp','gif','pdf','md','markdown','txt','html','htm','xml'
  };

  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.xml')) return 'application/xml';
    return 'application/octet-stream';
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: _allowedExts.toList(),
    );
    if (res == null) return;

    int remaining = 3 - _attachments.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can attach up to 3 files.', style: GoogleFonts.poppins())),
      );
      return;
    }
    final picked = res.files.take(remaining);
    int rejected = 0;
    for (final f in picked) {
      if (f.bytes == null) continue;
      final ext = (f.extension ?? '').toLowerCase();
      if (!_allowedExts.contains(ext)) { rejected++; continue; }
      _attachments.add({
        'bytes': f.bytes!,
        'mime_type': _guessMime(f.name),
        'file_name': f.name,
      });
    }
    if (rejected > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some files were rejected (unsupported type).', style: GoogleFonts.poppins())),
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
  final overlay = Overlay.maybeOf(context);
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
    double top = topLeft.dy - previewH - 8; // try above first
    if (top < 8) top = topLeft.dy + size.height + 8; // otherwise below

    _imageHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
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

  void _showImageHoverOverlayForPillBytes(BuildContext pillContext, Uint8List bytes) {
    _removeImageHoverOverlay();
  final overlay = Overlay.maybeOf(context);
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
    double top = topLeft.dy - previewH - 8; // try above first
    if (top < 8) top = topLeft.dy + size.height + 8; // otherwise below

    _imageHoverOverlay = OverlayEntry(
      builder: (ctx) => Positioned(
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
                  bytes,
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
      builder: (ctx) => Dialog(
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
                  const Icon(Icons.image_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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
      builder: (ctx) => Dialog(
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
                  const Icon(Icons.image_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
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

  Future<String?> _createSignedUrl(SupabaseClient client, String path) async {
    try {
      final dynamic resp = await client.storage.from('user-uploads').createSignedUrl(path, 60 * 60);
      if (resp is String) return resp;
      if (resp is Map) {
        final v1 = resp['signedUrl'];
        if (v1 is String) return v1;
        final v2 = resp['signed_url'];
        if (v2 is String) return v2;
        final v3 = resp['url'];
        if (v3 is String) return v3;
      }
    } catch (_) {}
    return null;
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    () async {
      final client = Supabase.instance.client;
      final List<Map<String, dynamic>> out = [];

      // Only show 'Processing attachments…' when actually uploading bytes
      final hasUploadables = _attachments.any((a) => a['bytes'] is Uint8List);
      if (hasUploadables) setState(() => _uploading = true);

      // First handle any already-uploaded items (no uploading spinner)
      for (final a in _attachments.where((a) => a.containsKey('bucket') && a.containsKey('path'))) {
        final path = a['path'] as String;
        final signedUrl = await _createSignedUrl(client, path);
        final bucket = (a['bucket'] as String?) ?? 'user-uploads';
        out.add({
          'bucket': bucket,
          'path': path,
          'mime_type': a['mime_type'],
          'file_name': a['file_name'],
          if (signedUrl != null) 'signedUrl': signedUrl,
          // Prefer signedUrl for immediate use; backend will add bucket_url when persisting
          if (signedUrl != null) 'uri': signedUrl,
        });
      }

      // Handle attachments that only have a bucket_url (no path available)
      for (final a in _attachments.where((a) => !a.containsKey('path') && (a['bucket_url'] is String))) {
        final bukUrl = (a['bucket_url'] as String?) ?? '';
        out.add({
          'bucket_url': bukUrl,
          'mime_type': a['mime_type'],
          'file_name': a['file_name'],
          if (bukUrl.isNotEmpty) 'uri': bukUrl,
          if (bukUrl.isNotEmpty) 'signedUrl': bukUrl,
        });
      }

      // Then upload any raw bytes
      for (final a in _attachments.where((a) => !(a.containsKey('bucket') && a.containsKey('path')))) {
        final bytes = a['bytes'];
        final mime = (a['mime_type'] as String?) ?? 'application/octet-stream';
        final name = (a['file_name'] as String?) ?? 'file';
        if (bytes is Uint8List) {
          try {
            final folder = 'playground/uploads';
            final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$name';
            await client.storage.from('user-uploads').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mime, upsert: true),
            );
            final signedUrl = await _createSignedUrl(client, path);
            out.add({
              'bucket': 'user-uploads',
              'path': path,
              'mime_type': mime,
              'file_name': name,
              if (signedUrl != null) 'signedUrl': signedUrl,
              if (signedUrl != null) 'uri': signedUrl,
            });
          } catch (_) {
            // Do not include raw data in attached_files for consistency; surface an error instead
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload "$name"', style: GoogleFonts.poppins())),
              );
            }
          }
        }
      }

      // Uploading phase complete
      if (hasUploadables) setState(() => _uploading = false);

      final prov = ref.read(playgroundProvider);
      // Clear the input UI immediately upon dispatch
      _controller.clear();
      _attachments.clear();
      setState(() {});

      await prov.send(
        text: text,
        attachments: out,
      );
    }();
  }

  void _showArtifactPreview(int index) {
    final state = ref.read(playgroundProvider);
    if (state.artifacts.isEmpty) return;
    _artifactPreviewIndex = index.clamp(0, state.artifacts.length - 1);
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 72.0, right: 16.0),
            child: Material(
              color: const Color(0xFF191A20),
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              child: StatefulBuilder(
                builder: (ctx, setStateSB) {
                  final items = ref.read(playgroundProvider).artifacts;
                  if (items.isEmpty) return const SizedBox.shrink();
                  final art = items[_artifactPreviewIndex];
                  final type = art['artifact_type'] as String? ?? '';
                  final data = art['data'] as Map<String, dynamic>?;
                  // Map to tool preview shape
                  Map<String, dynamic> event;
                  if (type == 'project_card_preview') {
                    event = {
                      'name': 'project_card_preview',
                      'result': {'card': data},
                    };
                  } else if (type == 'todo_list') {
                    event = {
                      'name': 'todo_list_create',
                      'result': {'todo': data},
                    };
                  } else {
                    event = {
                      'name': type,
                      'result': {'data': data},
                    };
                  }
                  return Container(
                    width: 420,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              onPressed:
                                  _artifactPreviewIndex > 0
                                      ? () {
                                        setStateSB(() {
                                          _artifactPreviewIndex--;
                                        });
                                      }
                                      : null,
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white70,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                art['title'] as String? ?? 'Artifact',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              onPressed:
                                  _artifactPreviewIndex < items.length - 1
                                      ? () {
                                        setStateSB(() {
                                          _artifactPreviewIndex++;
                                        });
                                      }
                                      : null,
                              icon: const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ToolEventPreviews(
                          events: [event],
                          fetchCanvasPreview:
                              (path) => ref
                                  .read(playgroundProvider)
                                  .fetchCanvasFileContent(path),
                          openCanvas:
                              (path) => ref
                                  .read(playgroundProvider)
                                  .openCanvasFile(path),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCanvasTitle(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split('/');
    final file = parts.isNotEmpty ? parts.last : raw;
    final dot = file.lastIndexOf('.');
    String name = file;
    String ext = '';
    if (dot > 0) {
      name = file.substring(0, dot).replaceAll('_', ' ').replaceAll('-', ' ');
      ext = file.substring(dot + 1).toLowerCase();
    }
    if (ext.isEmpty) return name;
    return "$name  ·  $ext";
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied', style: GoogleFonts.poppins()),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openMostRecentCanvas() {
    final state = ref.read(playgroundProvider);
    if (state.canvasFiles.isEmpty) return;
    Map<String, dynamic>? latest;
    DateTime? latestTime;
    for (final f in state.canvasFiles) {
      final lm = f['last_modified'];
      DateTime? t;
      if (lm is String) {
        t = DateTime.tryParse(lm);
      } else if (lm is DateTime) {
        t = lm;
      }
      t ??= DateTime.fromMillisecondsSinceEpoch(0);
      if (latestTime == null || t.isAfter(latestTime)) {
        latestTime = t;
        latest = f;
      }
    }
    final path = latest?['path'] as String?;
    if (path != null && path.isNotEmpty) {
      ref.read(playgroundProvider).openCanvasFile(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final hasMessages = state.messages.isNotEmpty;
    final titleText =
        state.chatTitle?.isNotEmpty == true ? state.chatTitle! : 'Playground';
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF121216),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          // Let sidebar overlay over the AppBar area
          color: Colors.transparent,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0, // Prevent color change on scroll
            // Reserve space for the collapsed sidebar (70px) so AppBar content shifts right
            automaticallyImplyLeading: false,
            leadingWidth: 70 + 48, // collapsed sidebar width + icon space
            leading: Padding(
              padding: const EdgeInsets.only(left: 70),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            titleSpacing: 16,
            title: Text(
              titleText,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              if (state.artifacts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: InkWell(
                      onTap: () => _showArtifactPreview(0),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Artifacts',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (state.canvasFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: InkWell(
                      onTap: _openMostRecentCanvas,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.brush,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Canvas',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'New chat',
                onPressed: () => ref.read(playgroundProvider).newChat(),
                icon: const Icon(Icons.edit, color: Colors.white),
              ),
              if (state.streaming)
                const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: Center(child: MiniWave(size: 20)),
                ),
            ],
          ),
        ),
      ),
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
            transform: GradientRotation(2.356),
          ),
        ),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 8),
              child: child,
            ),
          ),
          child: Row(
            children: [
              PremiumSidebar(
                items: [
                  PremiumSidebarItem(
                    icon: Icons.home,
                    label: 'Home',
                    onTap: () => Navigator.of(context).pop(),
                    selected: false,
                  ),
                  PremiumSidebarItem(
                    icon: Icons.play_arrow_rounded,
                    label: 'Playground',
                    onTap: () {},
                    selected: true,
                  ),
                  PremiumSidebarItem(
                    icon: Icons.construction_rounded,
                    label: 'Build',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BuildPage()),
                    ),
                  ),
                  PremiumSidebarItem(
                    icon: Icons.school_rounded,
                    label: 'Learn',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LearnPage()),
                    ),
                  ),
                ],
                topPadding: 16,
                middle: _PlaygroundHistoryPanel(ref: ref),
              ),
              // Only the main content area is pushed below the AppBar; the sidebar touches the very top
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showCanvas = ref.watch(playgroundProvider).selectedCanvasPath != null;
                    return Row(
                      children: [
                        Expanded(
                          flex: showCanvas ? 4 : 2,
                          child: Stack(
                            children: [
                              _buildGlow(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: !hasMessages ? _buildLanding(context) : _buildConversation(context),
                              ),
                            ],
                          ),
                        ),
                        if (showCanvas)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, t, child) => Transform.translate(
                              offset: Offset((1 - t) * 100, 0),
                              child: Opacity(
                                opacity: t,
                                child: child,
                              ),
                            ),
                            child: Container(
                              width: constraints.maxWidth * 0.35,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1A1D29),
                                    Color(0xFF151824), 
                                    Color(0xFF111320)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border(
                                  left: BorderSide(color: Colors.white.withOpacity(0.12)),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(-2, 0),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Enhanced header with better styling
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      border: Border(
                                        bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF7F5AF0),
                                                Color(0xFF9D4EDD),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF7F5AF0).withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.code, color: Colors.white, size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Canvas Preview',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatCanvasTitle(ref.watch(playgroundProvider).selectedCanvasPath ?? ''),
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Close Canvas',
                                          onPressed: () => ref.read(playgroundProvider).closeCanvas(),
                                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Enhanced content area
                                  Expanded(
                                    child: ref.watch(playgroundProvider).loadingCanvas
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.2),
                                            ),
                                            child: const Center(child: MiniWave(size: 28)),
                                          )
                                        : _CanvasPreview(content: ref.watch(playgroundProvider).selectedCanvasContent ?? ''),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanding(BuildContext context) {
    // Landing hero with centered text and narrow (30%) input bar
    final width = MediaQuery.of(context).size.width;
    final inputWidth = width * 0.3; // 30%
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero canvas icon with colorful glow effect
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.92, end: 1.0),
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect layers
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEE7752).withOpacity(0.35),
                      const Color(0xFFE73C7E).withOpacity(0.25),
                      const Color(0xFF23A6D5).withOpacity(0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF12D8FA).withOpacity(0.45),
                      const Color(0xFFA6FFCB).withOpacity(0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              // Main canvas icon with colorful gradient stroke
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: const [
                      Color(0xFFEE7752),
                      Color(0xFFE73C7E),
                      Color(0xFF23A6D5),
                      Color(0xFF23D5AB),
                      Color(0xFFEE7752),
                    ],
                    stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    startAngle: 0.0,
                    endAngle: 6.283, // ~2pi
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE73C7E).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1420),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 32),
          Text(
            'Bring Your Ideas to Life',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Playground lets you build simple apps and prototypes',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: inputWidth.clamp(360, 720)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InputBar(
              controller: _controller,
              focusNode: _focusNode,
              attachments: _attachments,
              onPickFiles: _pickFiles,
              onRemoveAttachmentAt: _removeAttachmentAt,
              onSend: _send,
              uploading: _uploading,
              sending:
                  ref.watch(playgroundProvider).sending ||
                  ref.watch(playgroundProvider).streaming,
              onHoverImageEnterUrl: _showImageHoverOverlayForPill,
              onHoverImageEnterBytes: _showImageHoverOverlayForPillBytes,
              onHoverImageExit: _removeImageHoverOverlay,
              onOpenImageModalUrl: _showImageModal,
              onOpenImageModalBytes: _showImageModalBytes,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final width = MediaQuery.of(context).size.width;
    final columnMaxWidth = width * 0.5; // 50%
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ListView.builder(
                  controller: _conversationScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                final m = state.messages[index];
                final isUser = m.sender == 'user';
                final isStreamingLastAI = !isUser && index == state.messages.length - 1 && state.streaming;
                // removed unused isLastAI local variable
                return Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: columnMaxWidth.clamp(420, 900),
                    ),
                    child: Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isUser
                                  ? AppColors.darkerAccent
                                  : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft:
                                isUser
                                    ? const Radius.circular(18)
                                    : const Radius.circular(6),
                            bottomRight:
                                isUser
                                    ? const Radius.circular(6)
                                    : const Radius.circular(18),
                          ),
                          border: null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser &&
                                (m.thoughts?.isNotEmpty == true)) ...[
                              _ThoughtsAccordion(thoughts: m.thoughts!),
                              const SizedBox(height: 10),
                            ],
                            if (isUser && m.attachments.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: m.attachments.map((a) {
                                  final name = a['file_name'] as String? ?? 'file';
                                  final mime = a['mime_type'] as String? ?? 'application/octet-stream';
                                  final signedUrl = a['signedUrl'] as String?;
                                  final uri = a['uri'] as String?;
                                  final bucketUrl = a['bucket_url'] as String?;
                                  final isImage = mime.startsWith('image/');
                                  final url = (signedUrl != null && signedUrl.isNotEmpty)
                                      ? signedUrl
                                      : ((uri != null && uri.isNotEmpty)
                                          ? uri
                                          : ((bucketUrl != null && bucketUrl.isNotEmpty) ? bucketUrl : null));
                                  if (isImage && (url != null)) {
                                    return InkWell(
                                      onTap: () => _showImageModal(url, name),
                                      child: Container(
                                        width: 260,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.image_outlined, color: Colors.white70, size: 14),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                url,
                                                height: 140,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  // Non-image or missing URL fallback to pill
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.attach_file, color: Colors.white70, size: 14),
                                        const SizedBox(width: 6),
                                        Text('$name · $mime', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (!isUser && isStreamingLastAI && (m.content.trim().isEmpty || m.content.toLowerCase().contains('thinking')))
                              const ThinkingDotsLoader(size: 56)
                            else
                              _SegmentedMarkdown(
                                data: m.content,
                                inlineEvents:
                                    (!isUser &&
                                            (m.toolResults?['events'] is List))
                                        ? List<Map<String, dynamic>>.from(
                                          m.toolResults!['events'] as List,
                                        )
                                        : const [],
                                fetchCanvasPreview:
                                    (path) => ref
                                        .read(playgroundProvider)
                                        .fetchCanvasFileContent(path),
                                openCanvas:
                                    (path) => ref
                                        .read(playgroundProvider)
                                        .openCanvasFile(path),
                                textStyle: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 2.2,
                                ),
                              ),
                            if (!isUser) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Copy',
                                    onPressed:
                                        () => _copyToClipboard(
                                          context,
                                          m.content,
                                        ),
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!isStreamingLastAI) ...[
                                    IconButton(
                                      tooltip: 'Like',
                                      onPressed:
                                          () => ref
                                              .read(playgroundProvider)
                                              .saveMessageFeedback(
                                                messageId: m.id,
                                                kind:
                                                    m.feedback == 'like'
                                                        ? null
                                                        : 'like',
                                              ),
                                      icon: Icon(
                                        m.feedback == 'like'
                                            ? Icons.thumb_up_alt
                                            : Icons.thumb_up_alt_outlined,
                                        color:
                                            m.feedback == 'like'
                                                ? AppColors.accent
                                                : Colors.white70,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Dislike',
                                      onPressed:
                                          () => ref
                                              .read(playgroundProvider)
                                              .saveMessageFeedback(
                                                messageId: m.id,
                                                kind:
                                                    m.feedback == 'dislike'
                                                        ? null
                                                        : 'dislike',
                                              ),
                                      icon: Icon(
                                        m.feedback == 'dislike'
                                            ? Icons.thumb_down_alt
                                            : Icons.thumb_down_alt_outlined,
                                        color:
                                            m.feedback == 'dislike'
                                                ? AppColors.accent
                                                : Colors.white70,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Scroll to bottom button overlay
          ScrollToBottomButton(
            isVisible: _showScrollToBottom,
            onPressed: _scrollToBottom,
          ),
        ],
      ),
    ),
    // Bottom input, 50% width, identical to Home
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (width * 0.5).clamp(480, 900),
              ),
              child: _InputBar(
                controller: _controller,
                focusNode: _focusNode,
                attachments: _attachments,
                onPickFiles: _pickFiles,
                onRemoveAttachmentAt: _removeAttachmentAt,
                onSend: _send,
                uploading: _uploading,
                onHoverImageExit: _removeImageHoverOverlay,
                onHoverImageEnterUrl: _showImageHoverOverlayForPill,
                onHoverImageEnterBytes: _showImageHoverOverlayForPillBytes,
                onOpenImageModalUrl: _showImageModal,
                onOpenImageModalBytes: _showImageModalBytes,
                sending: state.sending || state.streaming,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlow() {
    return Stack(
      children: [
        Positioned(
          top: 80,
          left: -120,
          child: _glowCircle(
            color: AppColors.accent.withOpacity(0.28),
            size: 360,
          ),
        ),
        Positioned(
          bottom: -60,
          right: -80,
          child: _glowCircle(
            color: Colors.purpleAccent.withOpacity(0.12),
            size: 300,
          ),
        ),
      ],
    );
  }

  Widget _glowCircle({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _PlaygroundHistoryPanel extends StatelessWidget {
  final WidgetRef ref;
  const _PlaygroundHistoryPanel({required this.ref});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final chats = state.chats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              const Icon(Icons.history, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text('History', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 16),
                onPressed: () => ref.read(playgroundProvider).fetchChats(),
              ),
            ],
          ),
        ),
        // Remove divider to blend with sidebar
        const SizedBox(height: 4),
        Expanded(
          child: chats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No chats yet',
                      style: GoogleFonts.poppins(color: Colors.white54),
                    ),
                  ),
                )
        : ListView.separated(
          padding: const EdgeInsets.all(8),
                  itemBuilder: (ctx, i) {
                    final c = chats[i];
                    final title = (c['title'] as String?)?.trim().isNotEmpty == true
                        ? c['title'] as String
                        : 'Untitled Chat';
                    return InkWell(
                      onTap: () async {
                        await ref.read(playgroundProvider).loadChat(c['id'] as String);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        decoration: BoxDecoration(
                          // Blend with sidebar background; remove borders
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white60, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.95), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemCount: chats.length,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(playgroundProvider).newChat(),
              style: OutlinedButton.styleFrom(
                // Make bottom button blend; transparent border
                side: const BorderSide(color: Colors.transparent),
                foregroundColor: Colors.white70,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: Text('New chat', style: GoogleFonts.poppins(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CanvasPreview extends StatelessWidget {
  final String content;
  const _CanvasPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with file info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${content.split('\n').length} lines',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Content area with better padding and scrolling
          Expanded(
            child: Container(
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  content.isEmpty ? '// Canvas content will appear here...' : content,
                  style: GoogleFonts.jetBrainsMono(
                    color: content.isEmpty ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.6,
                    fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Map<String, dynamic>> attachments;
  final VoidCallback onPickFiles;
  final void Function(int index) onRemoveAttachmentAt;
  final VoidCallback onSend;
  final bool sending;
  final bool uploading;
  // URL preview handlers
  final void Function(String url, String title)? onOpenImageModalUrl;
  final void Function(BuildContext pillContext, String url)? onHoverImageEnterUrl;
  // Bytes preview handlers (pre-upload)
  final void Function(Uint8List bytes, String title)? onOpenImageModalBytes;
  final void Function(BuildContext pillContext, Uint8List bytes)? onHoverImageEnterBytes;
  final VoidCallback? onHoverImageExit;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.attachments,
    required this.onPickFiles,
    required this.onRemoveAttachmentAt,
    required this.onSend,
    required this.sending,
    required this.uploading,
    this.onOpenImageModalUrl,
    this.onHoverImageEnterUrl,
    this.onOpenImageModalBytes,
    this.onHoverImageEnterBytes,
    this.onHoverImageExit,
  });

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
              // Top: attachments chips + text field
              if (attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 0; i < attachments.length; i++)
                        Builder(builder: (pillCtx) {
                          final att = attachments[i];
                          final name = att['file_name'] as String? ?? 'file';
                          final mime = att['mime_type'] as String? ?? 'application/octet-stream';
                          final isImage = mime.startsWith('image/');
                          final bytes = att['bytes'];
                          final signedUrl = att['signedUrl'] as String?;
                          final uri = att['uri'] as String?;
                          final bucketUrl = att['bucket_url'] as String?;
                          final url = signedUrl?.isNotEmpty == true
                              ? signedUrl
                              : (uri?.isNotEmpty == true ? uri : (bucketUrl?.isNotEmpty == true ? bucketUrl : null));
                          final pill = Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isImage ? Icons.image_outlined : Icons.attach_file, color: Colors.white70, size: 14),
                                const SizedBox(width: 6),
                                Text(name, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => onRemoveAttachmentAt(i),
                                  child: const Icon(Icons.close, color: Colors.white60, size: 14),
                                )
                              ],
                            ),
                          );
                          if (isImage) {
                            // Pre-upload bytes hover/modal
                            if (bytes is Uint8List) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => onHoverImageEnterBytes?.call(pillCtx, bytes),
                                onExit: (_) => onHoverImageExit?.call(),
                                child: GestureDetector(
                                  onTap: () => onOpenImageModalBytes?.call(bytes, name),
                                  child: pill,
                                ),
                              );
                            }
                            // Post-upload URL hover/modal
                            if (url != null && url.isNotEmpty) {
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                onEnter: (_) => onHoverImageEnterUrl?.call(pillCtx, url),
                                onExit: (_) => onHoverImageExit?.call(),
                                child: GestureDetector(
                                  onTap: () => onOpenImageModalUrl?.call(url, name),
                                  child: pill,
                                ),
                              );
                            }
                          }
                          return pill;
                        }),
                    ],
                  ),
                ),
              TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 6,
                minLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ask or start building…',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => (sending || uploading) ? null : onSend(),
              ),
              const SizedBox(height: 8),
              // Bottom: attach + send buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    IconButton(
                      onPressed: (sending || uploading) ? null : onPickFiles,
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                    ),
                  ]),
                  ElevatedButton(
                    onPressed: (sending || uploading) ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: (sending || uploading)
                        ? Row(
                            children: const [
                              SizedBox(width: 22, height: 22, child: MiniWave(size: 22)),
                            ],
                          )
                        : const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                ],
              ),
              if (uploading)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Processing attachments…',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThoughtsAccordion extends StatefulWidget {
  final String thoughts;
  const _ThoughtsAccordion({required this.thoughts});

  @override
  State<_ThoughtsAccordion> createState() => _ThoughtsAccordionState();
}

class _ThoughtsAccordionState extends State<_ThoughtsAccordion> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Thoughts',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: _SegmentedMarkdown(
                    data: widget.thoughts,
                    textStyle: GoogleFonts.robotoMono(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _ToolEventsAccordion extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  const _ToolEventsAccordion({required this.events});

  @override
  State<_ToolEventsAccordion> createState() => _ToolEventsAccordionState();
}

class _ToolEventsAccordionState extends State<_ToolEventsAccordion> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.extension,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tool activity',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    widget.events.map((e) {
                      final name = e['name'] as String? ?? 'tool';
                      final res = e['result'];
                      final text = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(res);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              text,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// Segmented Markdown that avoids builders by splitting fenced code blocks
class _SegmentedMarkdown extends StatelessWidget {
  final String data;
  final TextStyle textStyle;
  final List<Map<String, dynamic>> inlineEvents;
  final Future<String?> Function(String path)? fetchCanvasPreview;
  final void Function(String path)? openCanvas;
  const _SegmentedMarkdown({
    required this.data,
    required this.textStyle,
    this.inlineEvents = const [],
    this.fetchCanvasPreview,
    this.openCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final parts = _parseSegments(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in parts)
          if (part.isToolMarker)
            _renderInlineTool(part.toolId, context)
          else if (part.isCode)
            PlaygroundCodeBlock(code: part.text, language: part.language)
          else
            MarkdownBody(
              data: part.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: textStyle,
                code: GoogleFonts.robotoMono(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  color: Colors.white.withOpacity(0.95),
                  fontSize: (textStyle.fontSize ?? 14) - 1,
                ),
              ),
            ),
      ],
    );
  }

  static List<_Segment> _parseSegments(String input) {
    final lines = input.split('\n');
    final segments = <_Segment>[];
    final buffer = StringBuffer();
    bool inFence = false;
    String fenceLang = '';

    for (final line in lines) {
      if (!inFence && line.trimLeft().startsWith('[tool:')) {
        // flush text buffer
        if (buffer.isNotEmpty) {
          segments.add(_Segment(text: buffer.toString(), isCode: false));
          buffer.clear();
        }
        final marker = line.trim();
        final idStr = marker.replaceAll(RegExp(r'[^0-9]'), '');
        final id = int.tryParse(idStr) ?? -1;
        segments.add(_Segment.tool(id));
        continue;
      }
      if (!inFence && line.trimLeft().startsWith('```')) {
        // flush text buffer
        if (buffer.isNotEmpty) {
          segments.add(_Segment(text: buffer.toString(), isCode: false));
          buffer.clear();
        }
        inFence = true;
        final afterTicks = line.trimLeft().substring(3).trim();
        fenceLang = afterTicks
            .split(RegExp(r'\s+'))
            .firstWhere((_) => true, orElse: () => '');
        continue;
      }
      if (inFence && line.trimLeft().startsWith('```')) {
        // end fence
        segments.add(
          _Segment(text: buffer.toString(), isCode: true, language: fenceLang),
        );
        buffer.clear();
        inFence = false;
        fenceLang = '';
        continue;
      }
      buffer.writeln(line);
    }
    if (buffer.isNotEmpty) {
      segments.add(
        _Segment(text: buffer.toString(), isCode: inFence, language: fenceLang),
      );
    }
    return segments;
  }

  Widget _renderInlineTool(int id, BuildContext context) {
    final event = inlineEvents.firstWhere(
      (e) => (e['id'] as int?) == id,
      orElse: () => const {},
    );
    if (event.isEmpty) {
      // Show a subtle in-progress chip if id not found yet
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tool running…',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final name = event['name'] as String? ?? '';
    final result = event['result'];
    // Reuse existing previews when possible
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ToolEventPreviews(
        events: [
          {'name': name, 'result': result},
        ],
        fetchCanvasPreview: fetchCanvasPreview ?? (_) async => null,
        openCanvas: openCanvas ?? (_) {},
      ),
    );
  }
}

class _Segment {
  final String text;
  final bool isCode;
  final String language;
  final bool isToolMarker;
  final int toolId;
  _Segment({
    required this.text,
    required this.isCode,
    this.language = '',
    this.isToolMarker = false,
    this.toolId = -1,
  });
  factory _Segment.tool(int id) =>
      _Segment(text: '', isCode: false, isToolMarker: true, toolId: id);
}
