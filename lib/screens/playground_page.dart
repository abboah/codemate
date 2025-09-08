import 'dart:ui';
import 'dart:async';
import 'dart:math';
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
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
// Conditional import: on web use HtmlElementView-based preview, otherwise stub
import 'package:codemate/widgets/canvas_html_preview_stub.dart'
    if (dart.library.html) 'package:codemate/widgets/canvas_html_preview_web.dart';
import 'package:codemate/utils/download_helper.dart' as download_helper;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:codemate/components/ide/diff_preview.dart';
import 'package:codemate/components/ide/diff_side_by_side.dart';
import 'package:codemate/widgets/template_prompt_pills.dart';
import 'package:codemate/supabase_config.dart';

class PlaygroundPage extends ConsumerStatefulWidget {
  const PlaygroundPage({super.key});

  @override
  ConsumerState<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends ConsumerState<PlaygroundPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> _attachments = [];
  bool _uploading =
      false; // show 'Processing attachments…' while uploading on send
  int _artifactPreviewIndex = 0;
  // Composer image hover preview overlay
  OverlayEntry? _imageHoverOverlay;
  // Scroll controller for conversation and scroll-to-bottom button
  final ScrollController _conversationScrollController = ScrollController();
  bool _showScrollToBottom = false;
  // Auto-scroll scheduling flag to avoid spamming animations while streaming
  bool _autoScrollScheduled = false;
  // Throttle state updates from scroll listener
  int _lastScrollCheckMs = 0;
  // Canvas view mode: 'code' or 'preview'
  final ValueNotifier<String> _canvasViewMode = ValueNotifier<String>('code');
  String? _lastCanvasPath; // to reset view mode when switching files
  // Split ratio between conversation (left) and canvas (right). 0.6 = 60% left.
  double _splitRatio = 0.5;
  static const double _minPaneRatio = 0.2; // 20%
  static const double _maxPaneRatio = 0.8; // 80%
  bool _canvasFullscreen = false;

  // Magic overlay state (for special prompt streaming)
  bool _magicActive = false; // a special prompt is in-flight
  bool _showMagicOverlay = false; // overlay visibility
  bool _loadingFacts = false;
  List<String> _magicFacts = const [];
  int _magicFactIndex = 0;
  Timer? _magicTicker;

  @override
  void initState() {
    super.initState();
    // Preload chats so the sidebar history shows up immediately on Playground
    Future.microtask(() {
      try {
        ref.read(playgroundProvider).fetchChats();
      } catch (_) {}
    });

    // Add scroll listener for scroll-to-bottom button
    _conversationScrollController.addListener(_onScroll);

    // Compute initial state after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onScroll(force: true);
    });
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
    _stopMagicOverlay(immediate: true);
    super.dispose();
  }

  void _onScroll({bool force = false}) {
    if (!_conversationScrollController.hasClients) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastScrollCheckMs < 80) return; // ~12.5 fps throttle
    _lastScrollCheckMs = now;

    final metrics = _conversationScrollController.position;
    // Consider "at bottom" when there's very little content below the viewport
    final extentAfter =
        metrics
            .extentAfter; // distance from bottom of viewport to bottom of content
    final shouldShow = extentAfter > 48 && metrics.maxScrollExtent > 100;

    if (shouldShow != _showScrollToBottom) {
      if (mounted) {
        setState(() {
          _showScrollToBottom = shouldShow;
        });
      }
    }
  }

  void _scrollToBottom() {
    _conversationScrollController.animateTo(
      _conversationScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleAutoScrollToBottom() {
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted) return;
      if (!_conversationScrollController.hasClients) return;
      final pos = _conversationScrollController.position;
      final target = pos.maxScrollExtent;
      // Use a short animation to keep it smooth
      _conversationScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
    });
  }

  Future<void> _showFileSwitcherMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(playgroundProvider);
    final files = state.canvasFiles;
    if (files.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No canvas files yet')));
      return;
    }
    final current = state.selectedCanvasPath;
    String? selected;
    // Suspend HTML iframe interactions while bottom sheet is open to avoid click-through
    try {
      CanvasHtmlOverlayController.instance.suspend();
      selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF0F1420),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Canvas files',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    cacheExtent: 600.0,
                    itemCount: files.length,
                    itemBuilder: (c, i) {
                      final f = files[i];
                      final path = f['path'] as String? ?? '';
                      final desc = (f['description'] as String?)?.trim();
                      final label =
                          (desc != null && desc.isNotEmpty)
                              ? desc
                              : _formatCanvasTitle(path);
                      final isCurrent = current == path;
                      return RepaintBoundary(
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.insert_drive_file,
                            color:
                                isCurrent
                                    ? const Color(0xFF7F5AF0)
                                    : Colors.white70,
                          ),
                          title: Text(
                            label,
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          subtitle: Text(
                            path,
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing:
                              isCurrent
                                  ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF7F5AF0),
                                  )
                                  : null,
                          onTap: () => Navigator.pop(ctx, path),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } finally {
      CanvasHtmlOverlayController.instance.resume();
    }
    if (selected != null && selected.isNotEmpty && selected != current) {
      await ref.read(playgroundProvider).openCanvasFile(selected);
    }
  }

  static const Set<String> _allowedExts = {
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'pdf',
    'md',
    'markdown',
    'txt',
    'html',
    'htm',
    'xml',
  };

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
        SnackBar(
          content: Text(
            'You can attach up to 3 files.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }
    final picked = res.files.take(remaining);
    int rejected = 0;
    for (final f in picked) {
      if (f.bytes == null) continue;
      final ext = (f.extension ?? '').toLowerCase();
      if (!_allowedExts.contains(ext)) {
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
    Uint8List bytes,
  ) {
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
          // Prefer signedUrl for immediate use; backend will add bucket_url when persisting
          if (signedUrl != null) 'uri': signedUrl,
        });
      }

      // Handle attachments that only have a bucket_url (no path available)
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

      // Then upload any raw bytes
      for (final a in _attachments.where(
        (a) => !(a.containsKey('bucket') && a.containsKey('path')),
      )) {
        final bytes = a['bytes'];
        final mime = (a['mime_type'] as String?) ?? 'application/octet-stream';
        final name = (a['file_name'] as String?) ?? 'file';
        if (bytes is Uint8List) {
          try {
            final folder = 'playground/uploads';
            final path =
                '$folder/${DateTime.now().millisecondsSinceEpoch}_$name';
            await client.storage
                .from('user-uploads')
                .uploadBinary(
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
                SnackBar(
                  content: Text(
                    'Failed to upload "$name"',
                    style: GoogleFonts.poppins(),
                  ),
                ),
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

      await prov.send(text: text, attachments: out);
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
                                        setStateSB(() { _artifactPreviewIndex--; });
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

  // Magic overlay lifecycle
  void _beginMagicOverlay() {
    if (_magicActive) return; // already active
    _magicActive = true;
    _showMagicOverlay = true;
    _loadingFacts = true;
    _magicFacts = const [];
    _magicFactIndex = 0;
    if (mounted) setState(() {});
    () async {
      // Initial fetch
      try {
        final facts = await _fetchProgrammingFacts(count: 8);
        if (!mounted) return;
        setState(() {
          _magicFacts = facts.isNotEmpty ? facts : _fallbackFacts;
          _loadingFacts = false;
          _magicFactIndex = 0;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _magicFacts = _fallbackFacts;
          _loadingFacts = false;
          _magicFactIndex = 0;
        });
      }
      // Poll backend every 5s to refresh facts (as requested)
      _magicTicker?.cancel();
      _magicTicker = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (!mounted || !_showMagicOverlay) return;
        try {
          final refreshed = await _fetchProgrammingFacts(count: 8);
          if (!mounted || !_showMagicOverlay) return;
          if (refreshed.isNotEmpty) {
            setState(() {
              _magicFacts = refreshed;
              _magicFactIndex = (_magicFactIndex + 1) % _magicFacts.length;
            });
          }
        } catch (_) {
          // keep existing facts on error
        }
      });
    }();
  }

  void _stopMagicOverlay({bool immediate = false}) {
    _magicActive = false;
    _magicTicker?.cancel();
    _magicTicker = null;
    if (!mounted) return;
    if (immediate) {
      _showMagicOverlay = false;
      setState(() {});
      return;
    }
    setState(() {
      _showMagicOverlay = false;
    });
  }

  Future<List<String>> _fetchProgrammingFacts({int count = 8}) async {
    try {
      final origin = getFunctionsOrigin();
      final uri = Uri.parse("$origin/fact-generator?count=$count");
      final resp = await http.get(uri, headers: {
        'Accept': 'application/json',
      });
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> json = jsonDecode(resp.body);
        final list = (json['facts'] as List?)?.cast<dynamic>() ?? const [];
        final facts = list
            .map((e) => e.toString())
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return facts;
      }
    } catch (_) {}
    return _fallbackFacts;
  }

  static const List<String> _fallbackFacts = [
    'The first computer bug was a real moth found in 1947.',
    'Python is named after Monty Python, not the snake.',
    'CSS stands for Cascading Style Sheets—order matters!',
    'JavaScript was created in just 10 days in 1995.',
    'In Git, HEAD is just a pointer to your current branch.',
    'SQL is declarative: you say what you want, not how to get it.',
    'HTTP/2 multiplexes multiple streams over one connection.',
    'Rust’s borrow checker prevents data races at compile time.',
  ];

  Widget _buildMagicOverlay(BuildContext context) {
    final screen = MediaQuery.of(context).size;
  // Slightly narrower modal for balanced design
  final cardWidth = (screen.width * 0.56).clamp(640.0, 980.0);
    final fact = (_magicFacts.isNotEmpty)
        ? _magicFacts[_magicFactIndex % _magicFacts.length]
        : 'Fetching a cool programming fact…';
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                Colors.black.withOpacity(0.75),
                Colors.black.withOpacity(0.85),
                Colors.black.withOpacity(0.95),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Center wider card with side-by-side content
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  width: cardWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF7F5AF0).withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const SweepGradient(
                                      colors: [
                                        Color(0xFF7F5AF0), 
                                        Color(0xFF9D4EDD), 
                                        Color(0xFF23A6D5), 
                                        Color(0xFF12D8FA),
                                        Color(0xFF7F5AF0)
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7F5AF0).withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF23A6D5).withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sit back and let Robin do the work…',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _stopMagicOverlay(),
                            icon: const Icon(Icons.visibility, color: Colors.white70, size: 18),
                            label: Text(
                              'See the action',
                              style: GoogleFonts.poppins(
                                color: Colors.white70, 
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (ctx, c) {
                          final isNarrow = c.maxWidth < 840;
                          final leftContent = Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.06),
                                  Colors.white.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Relax while we build',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Robin is busy crafting your request. You can close this to watch the progress anytime.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.6,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7F5AF0), Color(0xFF9D4EDD), Color(0xFF23A6D5)],
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7F5AF0).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                          final rightContent = Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.06),
                                  Colors.white.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFC107).withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.lightbulb, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Did you know?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: Text(
                                    _loadingFacts ? 'Fetching a cool programming fact…' : fact,
                                    key: ValueKey(_loadingFacts ? 'loading' : fact),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.85),
                                      height: 1.6,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [leftContent, const SizedBox(height: 12), rightContent],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: leftContent),
                              const SizedBox(width: 12),
                              Expanded(child: rightContent),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    // Auto-scroll while streaming to keep viewport pinned to bottom.
    // Note: ref.listen must be used inside build for ConsumerState widgets.
    ref.listen(playgroundProvider, (previous, next) {
      if (next.streaming ||
          (previous?.streaming == true && next.streaming == false)) {
        _scheduleAutoScrollToBottom();
      }
      if ((previous?.messages.length ?? 0) != next.messages.length &&
          next.streaming) {
        _scheduleAutoScrollToBottom();
      }
      // Open overlay when streaming begins (any message processing)
      if ((previous?.streaming != true) && next.streaming == true) {
        _beginMagicOverlay();
      }
      // Close magic overlay automatically when streaming completes
      if ((previous?.streaming == true) && next.streaming == false) {
        if (_showMagicOverlay) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _stopMagicOverlay(immediate: true);
          });
        }
      }
    });
    // Reset view mode when the selected canvas file changes
    if (state.selectedCanvasPath != _lastCanvasPath) {
      _lastCanvasPath = state.selectedCanvasPath;
      _canvasViewMode.value = 'code';
    }
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
            colors: [Color(0xFF0A0A0D), Color(0xFF121216), Color(0xFF1A1A20)],
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
          builder:
              (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 8),
                  child: child,
                ),
              ),
          child: Row(
            children: [
              // Sidebar quick slide-in for immersive entry
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset((1 - t) * -12, 0),
                      child: child,
                    ),
                  );
                },
                child: PremiumSidebar(
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
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BuildPage(),
                            ),
                          ),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.school_rounded,
                      label: 'Learn',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LearnPage(),
                            ),
                          ),
                    ),
                  ],
                  topPadding: 16,
                  gapBelowTopIcon: 8, // reduce unusual gap in Playground
                  expandTopIconHitBox: true, // make whole area clickable
                  middle: _PlaygroundHistoryPanel(ref: ref),
                ),
              ),
              // Only the main content area is pushed below the AppBar; the sidebar touches the very top
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showCanvas =
                          ref.watch(playgroundProvider).selectedCanvasPath !=
                          null;
                      if (!showCanvas) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Stack(
                                children: [
                                  // Ambient particles behind the content
                                  _buildAnimatedParticles(),
                                  _buildGlow(),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    child: Stack(
                                      children: [
                                        !hasMessages
                                            ? _buildLanding(context)
                                            : _buildConversation(context),
                                        if (_showMagicOverlay) _buildMagicOverlay(context),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // With canvas open: sized panes with draggable separator
                      const grabberW = 8.0;
                      final totalW = constraints.maxWidth;
                      final contentW = (totalW - grabberW).clamp(0.0, totalW);
                      final leftW = (contentW * _splitRatio).clamp(
                        contentW * _minPaneRatio,
                        contentW * _maxPaneRatio,
                      );
                      final rightW = contentW - leftW;
                      return Stack(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: leftW,
                                child: Stack(
                                  children: [
                                    // Ambient particles behind the content
                                    _buildAnimatedParticles(),
                                    _buildGlow(),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: Stack(
                                        children: [
                                          !hasMessages
                                              ? _buildLanding(context)
                                              : _buildConversation(context),
                                          if (_showMagicOverlay) _buildMagicOverlay(context),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Grabber
                              MouseRegion(
                                cursor: SystemMouseCursors.resizeColumn,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onHorizontalDragUpdate: (details) {
                                    final newLeft = (leftW + details.delta.dx)
                                        .clamp(
                                          contentW * _minPaneRatio,
                                          contentW * _maxPaneRatio,
                                        );
                                    setState(() {
                                      _splitRatio =
                                          (contentW <= 0)
                                              ? 0.5
                                              : (newLeft / contentW);
                                    });
                                  },
                                  child: Container(
                                    width: grabberW,
                                    height: double.infinity,
                                    color: Colors.white.withOpacity(0.02),
                                    child: Center(
                                      child: Container(
                                        width: 2,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Canvas pane
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder:
                                    (context, t, child) => Transform.translate(
                                      offset: Offset((1 - t) * 100, 0),
                                      child: Opacity(opacity: t, child: child),
                                    ),
                                child: SizedBox(
                                  width: rightW,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1A1D29),
                                          Color(0xFF151824),
                                          Color(0xFF111320),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border(
                                        left: BorderSide(
                                          color: Colors.white.withOpacity(0.12),
                                        ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.03,
                                            ),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.white.withOpacity(
                                                  0.08,
                                                ),
                                              ),
                                            ),
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, head) {
                                              final compact =
                                                  head.maxWidth < 480;
                                              final ultra = head.maxWidth < 360;
                                              final state = ref.watch(
                                                playgroundProvider,
                                              );
                                              final currentPath =
                                                  state.selectedCanvasPath ??
                                                  '';
                                              final desc =
                                                  (state.selectedCanvasMeta?['description']
                                                          as String?)
                                                      ?.trim();
                                              final currentLabel =
                                                  (desc != null &&
                                                          desc.isNotEmpty)
                                                      ? desc
                                                      : (currentPath
                                                              .split('/')
                                                              .isNotEmpty
                                                          ? currentPath
                                                              .split('/')
                                                              .last
                                                          : currentPath);
                                              return Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const LinearGradient(
                                                            colors: [
                                                              Color(0xFF7F5AF0),
                                                              Color(0xFF9D4EDD),
                                                            ],
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(
                                                            0xFF7F5AF0,
                                                          ).withOpacity(0.3),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                            0,
                                                            1,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.code,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (!compact)
                                                    Expanded(
                                                      child: InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        onTap: () async {
                                                          await _showFileSwitcherMenu(
                                                            context,
                                                            ref,
                                                          );
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 2,
                                                                horizontal: 4,
                                                              ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      'Canvas',
                                                                      style: GoogleFonts.poppins(
                                                                        color: Colors
                                                                            .white
                                                                            .withOpacity(
                                                                              0.6,
                                                                            ),
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      currentLabel,
                                                                      style: GoogleFonts.poppins(
                                                                        color:
                                                                            Colors.white,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                        fontSize:
                                                                            13,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      maxLines:
                                                                          1,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .arrow_drop_down,
                                                                color:
                                                                    Colors
                                                                        .white70,
                                                                size: 16,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    // Compact: show only a small file switcher icon button
                                                    IconButton(
                                                      tooltip:
                                                          'Switch canvas file',
                                                      onPressed: () async {
                                                        await _showFileSwitcherMenu(
                                                          context,
                                                          ref,
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.folder_open,
                                                        color: Colors.white70,
                                                        size: 18,
                                                      ),
                                                      iconSize: 18,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                      style: IconButton.styleFrom(
                                                        backgroundColor: Colors
                                                            .white
                                                            .withOpacity(0.05),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (!ultra) ...[
                                                    const SizedBox(width: 6),
                                                    _CanvasHeaderToggle(
                                                      mode: _canvasViewMode,
                                                      meta:
                                                          state
                                                              .selectedCanvasMeta,
                                                    ),
                                                  ],
                                                  const SizedBox(width: 6),
                                                  _VersionDropdown(ref: ref),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    tooltip:
                                                        _canvasFullscreen
                                                            ? 'Exit Fullscreen'
                                                            : 'View Fullscreen',
                                                    onPressed:
                                                        () => setState(() {
                                                          _canvasFullscreen =
                                                              !_canvasFullscreen;
                                                        }),
                                                    icon: Icon(
                                                      _canvasFullscreen
                                                          ? Icons
                                                              .fullscreen_exit
                                                          : Icons.fullscreen,
                                                      color: Colors.white70,
                                                      size: 18,
                                                    ),
                                                    iconSize: 18,
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: Colors
                                                          .white
                                                          .withOpacity(0.05),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _CanvasMoreMenu(ref: ref),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    tooltip: 'Close Canvas',
                                                    onPressed:
                                                        () =>
                                                            ref
                                                                .read(
                                                                  playgroundProvider,
                                                                )
                                                                .closeCanvas(),
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white70,
                                                      size: 18,
                                                    ),
                                                    iconSize: 18,
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 32,
                                                          minHeight: 32,
                                                        ),
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: Colors
                                                          .white
                                                          .withOpacity(0.05),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        // Preview banner when looking at a historical version
                                        _PreviewVersionBanner(ref: ref),
                                        Expanded(
                                          child: _CanvasPreviewHost(
                                            ref: ref,
                                            mode: _canvasViewMode,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_canvasFullscreen)
                            Positioned.fill(
                              child: Container(
                                color: const Color(0xFF0F1420),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, head) {
                                          final compact = head.maxWidth < 480;
                                          final ultra = head.maxWidth < 360;
                                          final state = ref.watch(
                                            playgroundProvider,
                                          );
                                          final currentPath =
                                              state.selectedCanvasPath ?? '';
                                          final desc =
                                              (state.selectedCanvasMeta?['description']
                                                      as String?)
                                                  ?.trim();
                                          final currentLabel =
                                              (desc != null && desc.isNotEmpty)
                                                  ? desc
                                                  : (currentPath
                                                          .split('/')
                                                          .isNotEmpty
                                                      ? currentPath
                                                          .split('/')
                                                          .last
                                                      : currentPath);
                                          return Row(
                                            children: [
                                              if (!compact)
                                                Expanded(
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    onTap: () async {
                                                      await _showFileSwitcherMenu(
                                                        context,
                                                        ref,
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 2,
                                                            horizontal: 4,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              currentLabel
                                                                      .isEmpty
                                                                  ? 'Canvas'
                                                                  : currentLabel,
                                                              style: GoogleFonts.poppins(
                                                                color:
                                                                    Colors
                                                                        .white70,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 14,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              maxLines: 1,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          const Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            color:
                                                                Colors.white70,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                IconButton(
                                                  tooltip: 'Switch canvas file',
                                                  onPressed: () async {
                                                    await _showFileSwitcherMenu(
                                                      context,
                                                      ref,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.folder_open,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                                  iconSize: 18,
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                ),
                                              if (!ultra) ...[
                                                const SizedBox(width: 6),
                                                _CanvasHeaderToggle(
                                                  mode: _canvasViewMode,
                                                  meta:
                                                      state.selectedCanvasMeta,
                                                ),
                                              ],
                                              const SizedBox(width: 6),
                                              _VersionDropdown(ref: ref),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: 'Exit Fullscreen',
                                                onPressed:
                                                    () => setState(() {
                                                      _canvasFullscreen = false;
                                                    }),
                                                icon: const Icon(
                                                  Icons.fullscreen_exit,
                                                  color: Colors.white70,
                                                  size: 18,
                                                ),
                                                iconSize: 18,
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              _CanvasMoreMenu(ref: ref),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    // Preview banner when looking at a historical version (fullscreen)
                                    _PreviewVersionBanner(ref: ref),
                                    Expanded(
                                      child: _CanvasPreviewHost(
                                        ref: ref,
                                        mode: _canvasViewMode,
                                      ),
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
            builder:
                (context, s, child) => Transform.scale(scale: s, child: child),
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
          // Quick-start templates (placed below the message bar)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: inputWidth.clamp(360, 720)),
            child: TemplatePromptPills(
              templates: const [

                TemplatePrompt(
                  face: 'Build a Todo App',
                  actual:
                      'Create a simple Todo application in a single HTML file with inline CSS and JS. Features: add, toggle, delete items; persist to localStorage; clean, responsive UI; keyboard-friendly. Provide concise explanation.'
                ),
                TemplatePrompt(
                  face: 'Markdown to HTML previewer',
                  actual:
                      'Build a single-file Markdown previewer (HTML + inline CSS/JS). Left textarea, right live preview. Use a tiny embedded parser or simple heuristics if no library. Style for readability.'
                ),
                TemplatePrompt(
                  face: 'Build Flight Sim with Three.js',
                  actual:
                      'You are in Playground Canvas mode. Build an interactive Flight Simulator using Three.js in a single self-contained HTML file with inline CSS and JS. Include basic controls: pitch, roll, yaw via keyboard, a skybox/gradient background, and a simple plane model (primitive shapes acceptable), with vegetation & clouds. Keep code readable and comment key parts. After implementing, suggest next enhancements briefly.'
                ),
                TemplatePrompt(
                  face: "Build a Snake game",
                  actual:
                      'Create a single HTML file with inline CSS/JS for a Retro-style Snake game. Features: classic gameplay, responsive design, high score system, and simple controls. Use placeholder graphics as needed.'
                )
              ],
              onSelect: (t) {
                _sendSpecialPrompt(face: t.face, actual: t.actual);
              },
              padding: const EdgeInsets.only(top: 8),
            ),
          ),
        ],
      ),
    );
  }

  // Sends a special prompt: user sees face text in the UI bubble styled specially,
  // but the backend only receives the actual detailed prompt. We tag locally for UI.
  Future<void> _sendSpecialPrompt({required String face, required String actual}) async {
    // Show face prompt in input for a tick to reuse existing send flow UX
    _controller.text = face;
    // Append a visual-only tag to the displayed message content; provider/backend will get `actual` only
    final display = '[SPECIAL PROMPT]\n$face';
    final attachments = List<Map<String, dynamic>>.from(_attachments);
    setState(() {
      _attachments.clear();
    });
    // Show magic overlay during special streaming
    _beginMagicOverlay();
    // Optimistically add a special-colored user bubble by sending via provider with a special flag
    await ref.read(playgroundProvider).sendSpecial(
      faceText: display,
      actualPrompt: actual,
      attachments: attachments,
      model: 'gemini-2.5-flash',
    );
    _controller.clear();
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 1000.0,
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  addRepaintBoundaries: true,
                  itemCount: state.messages.length,
                  itemBuilder: (context, index) {
                    final m = state.messages[index];
                    final isUser = m.sender == 'user';
          final isStreamingLastAI =
                        !isUser &&
                        index == state.messages.length - 1 &&
                        state.streaming;
          final isSpecial = m.isSpecial == true;
                    // removed unused isLastAI local variable
                    return RepaintBoundary(
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: columnMaxWidth.clamp(420, 900),
                          ),
                          child: Align(
                            alignment:
                                isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? (isSpecial ? Colors.purple.withOpacity(0.35) : AppColors.darkerAccent)
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
                                      children:
                                          m.attachments.map((a) {
                                            final name =
                                                a['file_name'] as String? ??
                                                'file';
                                            final mime =
                                                a['mime_type'] as String? ??
                                                'application/octet-stream';
                                            final signedUrl =
                                                a['signedUrl'] as String?;
                                            final uri = a['uri'] as String?;
                                            final bucketUrl =
                                                a['bucket_url'] as String?;
                                            final isImage = mime.startsWith(
                                              'image/',
                                            );
                                            final url =
                                                (signedUrl != null &&
                                                        signedUrl.isNotEmpty)
                                                    ? signedUrl
                                                    : ((uri != null &&
                                                            uri.isNotEmpty)
                                                        ? uri
                                                        : ((bucketUrl != null &&
                                                                bucketUrl
                                                                    .isNotEmpty)
                                                            ? bucketUrl
                                                            : null));
                                            if (isImage && (url != null)) {
                                              return InkWell(
                                                onTap:
                                                    () => _showImageModal(
                                                      url,
                                                      name,
                                                    ),
                                                child: Container(
                                                  width: 260,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.25),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.12),
                                                    ),
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .image_outlined,
                                                            color:
                                                                Colors.white70,
                                                            size: 14,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: GoogleFonts.poppins(
                                                                color:
                                                                    Colors
                                                                        .white70,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        child: Image.network(
                                                          url,
                                                          height: 140,
                                                          width:
                                                              double.infinity,
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
                                                color: Colors.black.withOpacity(
                                                  0.25,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.12),
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.attach_file,
                                                    color: Colors.white70,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$name · $mime',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (!isUser &&
                                      isStreamingLastAI &&
                                      (m.content.trim().isEmpty ||
                                          m.content.toLowerCase().contains(
                                            'thinking',
                                          )))
                                    const ThinkingDotsLoader(size: 56)
                                  else
                                    _SegmentedMarkdown(
                                      data: _displayContentForMessage(m),
                                      inlineEvents:
                                          (!isUser &&
                                                  (m.toolResults?['events']
                                                      is List))
                                              ? List<Map<String, dynamic>>.from(
                                                m.toolResults!['events']
                                                    as List,
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
                                        fontWeight: isUser ? FontWeight.w400 : FontWeight.w600,
                                      ),
                                    ),
                                  if (!isUser && !isStreamingLastAI) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Copy appears only after stream completes
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
                                    ),
                                  ],
                                ],
                              ),
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

  String _displayContentForMessage(dynamic m) {
    // If this is a special prompt bubble we created, strip the tag for display
    try {
      final isSpecial = (m as dynamic).isSpecial == true;
      final content = (m as dynamic).content as String? ?? '';
      if (isSpecial) {
        if (content.startsWith('[SPECIAL PROMPT]')) {
          return content.replaceFirst('[SPECIAL PROMPT]', '').trimLeft();
        }
      }
      return content;
    } catch (_) {
      return (m as dynamic).content as String? ?? '';
    }
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

  // Subtle ambient particles similar to Home; purely visual
  Widget _buildAnimatedParticles() {
    return IgnorePointer(
      child: Stack(
        children: List.generate(12, (index) {
          final rnd = Random(index);
          final size = 2.0 + rnd.nextDouble() * 4;
          final opacity = 0.08 + rnd.nextDouble() * 0.25;
          final int ms = 2600 + rnd.nextInt(3200);
          final screen = MediaQuery.of(context).size;
          final left = rnd.nextDouble() * screen.width;
          final top = rnd.nextDouble() * screen.height;
          return Positioned(
            left: left,
            top: top,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: ms),
              opacity: opacity,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withOpacity(opacity),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(opacity * 0.4),
                      blurRadius: size * 2,
                      spreadRadius: size * 0.5,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
              Text(
                'History',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white54,
                  size: 16,
                ),
                onPressed: () => ref.read(playgroundProvider).fetchChats(),
              ),
            ],
          ),
        ),
        // Remove divider to blend with sidebar
        const SizedBox(height: 4),
        Expanded(
          child:
              chats.isEmpty
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
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    cacheExtent: 800.0,
                    itemBuilder: (ctx, i) {
                      final c = chats[i];
                      final title =
                          (c['title'] as String?)?.trim().isNotEmpty == true
                              ? c['title'] as String
                              : 'Untitled Chat';
                      return RepaintBoundary(
                        child: InkWell(
                          onTap: () async {
                            await ref
                                .read(playgroundProvider)
                                .loadChat(c['id'] as String);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              // Blend with sidebar background; remove borders
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.white60,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

class _CanvasHeaderToggle extends StatelessWidget {
  final ValueNotifier<String> mode; // 'code' | 'preview'
  final Map<String, dynamic>? meta;
  const _CanvasHeaderToggle({required this.mode, required this.meta});

  bool get _shouldShowToggle {
    final t = (meta?['file_type'] as String?)?.toLowerCase();
    // Show when file type is not 'document' (i.e., code or unknown)
    return t != 'document';
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowToggle) return const SizedBox.shrink();
    return ValueListenableBuilder<String>(
      valueListenable: mode,
      builder: (context, value, _) {
        final isCode = value != 'preview';
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _togglePill(
                context,
                icon: Icons.visibility_outlined,
                label: 'Preview',
                selected: !isCode,
                onTap: () => mode.value = 'preview',
              ),
              _togglePill(
                context,
                icon: Icons.code,
                label: 'Code',
                selected: isCode,
                onTap: () => mode.value = 'code',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _togglePill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: selected ? 1.0 : 0.95,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? Colors.white.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasPreviewHost extends StatelessWidget {
  final WidgetRef ref;
  final ValueNotifier<String> mode;
  const _CanvasPreviewHost({required this.ref, required this.mode});

  bool get _isDocument {
    final t =
        (ref.watch(playgroundProvider).selectedCanvasMeta?['file_type']
                as String?)
            ?.toLowerCase();
    return t == 'document';
  }

  bool get _canImplementInCanvas {
    final v =
        ref
            .watch(playgroundProvider)
            .selectedCanvasMeta?['can_implement_in_canvas'];
    return v == true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final content = state.selectedCanvasContent ?? '';
    final loading = state.loadingCanvas;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child:
            loading
                ? const Center(child: MiniWave(size: 28))
                : (_isDocument
                    ? _DocumentMarkdown(content: content)
                    : ValueListenableBuilder<String>(
                      valueListenable: mode,
                      builder: (context, value, _) {
                        if (value == 'preview') {
                          if (!_canImplementInCanvas)
                            return const _PreviewNotSupported();
                          return _WebPreview(content: content);
                        }
                        // Default to code view
                        return _CodeView(content: content);
                      },
                    )),
      ),
    );
  }
}

class _CanvasMoreMenu extends StatelessWidget {
  final WidgetRef ref;
  const _CanvasMoreMenu({required this.ref});

  String _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.js')) return 'text/javascript';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.md') || lower.endsWith('.markdown'))
      return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.dart')) return 'text/plain';
    return 'text/plain';
  }

  Future<void> _downloadCurrent(BuildContext context) async {
    final state = ref.read(playgroundProvider);
    final path = state.selectedCanvasPath ?? 'file.txt';
    final content = state.selectedCanvasContent ?? '';
    final parts = path.split('/');
    final filename = parts.isNotEmpty ? parts.last : 'file.txt';
    final mime = _guessMime(filename);
    final ok = await download_helper.DownloadHelper.saveTextFile(
      filename: filename,
      mime: mime,
      content: content,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Downloaded $filename' : 'Failed to download $filename',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: const Color(0xFF1A1D29),
      icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
      itemBuilder:
          (ctx) => [
            PopupMenuItem<String>(
              value: 'download',
              child: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Download file',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
      onSelected: (v) async {
        if (v == 'download') {
          await _downloadCurrent(context);
        }
      },
      position: PopupMenuPosition.under,
    );
  }
}

class _DocumentMarkdown extends StatelessWidget {
  final String content;
  const _DocumentMarkdown({required this.content});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.2),
      padding: const EdgeInsets.all(16),
      child: Markdown(
        data: content,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          h1: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 28,
          ),
          h2: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 24,
          ),
          h3: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 20,
          ),
          h4: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 18,
          ),
          h5: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 16,
          ),
          h6: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: 14,
          ),
          p: GoogleFonts.inter(color: Colors.white, height: 1.7, fontSize: 15),
          blockquote: GoogleFonts.inter(color: Colors.white70, height: 1.7),
          listBullet: GoogleFonts.inter(color: Colors.white, height: 1.7),
          em: GoogleFonts.inter(
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
          strong: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          code: GoogleFonts.robotoMono(color: Colors.white),
        ),
      ),
    );
  }
}

class _CodeView extends StatefulWidget {
  final String content;
  const _CodeView({required this.content});
  @override
  State<_CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<_CodeView> {
  final ScrollController _v = ScrollController();
  final ScrollController _h = ScrollController();
  String _detectLanguage(String path, String code) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.dart')) return 'dart';
    if (lower.endsWith('.js') ||
        lower.endsWith('.mjs') ||
        lower.endsWith('.cjs'))
      return 'javascript';
    if (lower.endsWith('.ts') || lower.endsWith('.tsx')) return 'typescript';
    if (lower.endsWith('.jsx')) return 'jsx';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'html';
    if (lower.endsWith('.css')) return 'css';
    if (lower.endsWith('.json')) return 'json';
    if (lower.endsWith('.py')) return 'python';
    if (lower.endsWith('.java')) return 'java';
    if (lower.endsWith('.kt') || lower.endsWith('.kts')) return 'kotlin';
    if (lower.endsWith('.rs')) return 'rust';
    if (lower.endsWith('.go')) return 'go';
    if (lower.endsWith('.rb')) return 'ruby';
    if (lower.endsWith('.php')) return 'php';
    if (lower.endsWith('.swift')) return 'swift';
    if (lower.endsWith('.c') || lower.endsWith('.h')) return 'c';
    if (lower.endsWith('.cpp') ||
        lower.endsWith('.cc') ||
        lower.endsWith('.hpp'))
      return 'cpp';
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return 'markdown';
    // Shebang hints
    if (code.startsWith('#!') && code.contains('python')) return 'python';
    if (code.startsWith('#!') && code.contains('node')) return 'javascript';
    return 'plaintext';
  }

  @override
  Widget build(BuildContext context) {
    // Access selected path via Inherited widgets by using Consumer
    final state = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(playgroundProvider);
    final path = state.selectedCanvasPath ?? '';
    final lang = _detectLanguage(path, widget.content);
    // Vibrant, high-contrast custom theme
    const theme = {
      'root': TextStyle(
        backgroundColor: Color(0xFF0B0E14),
        color: Color(0xFFE6E6E6),
      ),
      'comment': TextStyle(
        color: Color(0xFF6A9955),
        fontStyle: FontStyle.italic,
      ),
      'quote': TextStyle(color: Color(0xFF6A9955), fontStyle: FontStyle.italic),
      'keyword': TextStyle(
        color: Color(0xFF569CD6),
        fontWeight: FontWeight.bold,
      ),
      'selector-tag': TextStyle(
        color: Color(0xFF4FC1FF),
        fontWeight: FontWeight.bold,
      ),
      'literal': TextStyle(color: Color(0xFFB5CEA8)),
      'section': TextStyle(color: Color(0xFF4EC9B0)),
      'link': TextStyle(color: Color(0xFFD7BA7D)),
      'subst': TextStyle(color: Color(0xFFE6E6E6)),
      'string': TextStyle(color: Color(0xFFCE9178)),
      'doctag': TextStyle(color: Color(0xFFD7BA7D)),
      'type': TextStyle(color: Color(0xFF4EC9B0)),
      'built_in': TextStyle(color: Color(0xFF4EC9B0)),
      'builtin-name': TextStyle(color: Color(0xFF4EC9B0)),
      'number': TextStyle(color: Color(0xFFB5CEA8)),
      'selector-id': TextStyle(color: Color(0xFF9CDCFE)),
      'selector-class': TextStyle(color: Color(0xFF4EC9B0)),
      'variable': TextStyle(color: Color(0xFF9CDCFE)),
      'template-variable': TextStyle(color: Color(0xFF9CDCFE)),
      'regexp': TextStyle(color: Color(0xFFD16969)),
      'symbol': TextStyle(color: Color(0xFFBD63C5)),
      'bullet': TextStyle(color: Color(0xFFD7BA7D)),
      'title': TextStyle(color: Color(0xFFE6E6E6), fontWeight: FontWeight.bold),
      'emphasis': TextStyle(
        color: Color(0xFFE6E6E6),
        fontStyle: FontStyle.italic,
      ),
      'strong': TextStyle(
        color: Color(0xFFE6E6E6),
        fontWeight: FontWeight.bold,
      ),
      'meta': TextStyle(color: Color(0xFF9CDCFE)),
      'meta-keyword': TextStyle(color: Color(0xFF9CDCFE)),
      'meta-string': TextStyle(color: Color(0xFFCE9178)),
      'attr': TextStyle(color: Color(0xFF9CDCFE)),
      'attribute': TextStyle(color: Color(0xFFD7BA7D)),
      'params': TextStyle(color: Color(0xFFE6E6E6)),
      'name': TextStyle(color: Color(0xFF4EC9B0)),
      'tag': TextStyle(color: Color(0xFF569CD6)),
    };
    return Container(
      color: const Color(0xFF0B0E14),
      child: Scrollbar(
        thumbVisibility: true,
        controller: _v,
        child: SingleChildScrollView(
          controller: _v,
          padding: const EdgeInsets.all(16),
          child: Scrollbar(
            thumbVisibility: true,
            controller: _h,
            notificationPredicate:
                (notif) => notif.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _h,
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.content.isEmpty
                    ? '// Canvas content will appear here...'
                    : widget.content,
                language: lang,
                theme: theme,
                textStyle: GoogleFonts.jetBrainsMono(
                  color:
                      widget.content.isEmpty
                          ? Colors.white.withOpacity(0.45)
                          : Colors.white,
                  fontSize: 13.5,
                  height: 1.6,
                  fontStyle:
                      widget.content.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionDropdown extends StatelessWidget {
  final WidgetRef ref;
  const _VersionDropdown({required this.ref});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final meta = state.selectedCanvasMeta;
    final current = (meta?['version_number'] as int?) ?? 1;
    final versions = state.selectedCanvasVersions;
    return PopupMenuButton<int>(
      tooltip: 'Canvas versions',
      position: PopupMenuPosition.under,
      color: const Color(0xFF1A1D29),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'v$current',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
      onOpened: () {
        // Suspend iframe so popup interactions are not eaten by HtmlElementView
        CanvasHtmlOverlayController.instance.suspend();
        final path = state.selectedCanvasPath;
        if (path != null && versions.isEmpty && !state.loadingVersions) {
          ref.read(playgroundProvider).fetchCanvasVersions(path);
        }
      },
      onCanceled: () {
        // Resume iframe once popup closes without selection
        CanvasHtmlOverlayController.instance.resume();
      },
      itemBuilder: (ctx) {
        if (state.loadingVersions) {
          return const [
            PopupMenuItem<int>(
              enabled: false,
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Loading versions…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
        if (versions.isEmpty) {
          return const [
            PopupMenuItem<int>(
              enabled: false,
              child: Text(
                'No versions yet',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ];
        }
        return versions.map((v) {
          final ver = (v['version_number'] as int?) ?? 0;
          final createdAt = (v['created_at'] as String?) ?? '';
          return PopupMenuItem<int>(
            value: ver,
            child: Row(
              children: [
                Text(
                  'v$ver',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    createdAt.replaceAll('T', ' ').split('.').first,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'View changes',
                  onPressed: () async {
                    // Close menu and open diff modal
                    Navigator.of(ctx).pop();
                    final path = state.selectedCanvasPath;
                    if (path == null) return;
                    try {
                      CanvasHtmlOverlayController.instance.suspend();
                      final res = await ref
                          .read(playgroundProvider)
                          .readVersionAndLatest(path: path, versionNumber: ver);
                      if (res == null) return;
                      // Inline diff modal with Preview/Restore/Close
                      // ignore: use_build_context_synchronously
                      await showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        backgroundColor: const Color(0xFF0F1420),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (bctx) {
                          return _InlineDiffModal(
                            path: path,
                            versionNumber: ver,
                            oldContent: res['old']!,
                            latestContent: res['latest']!,
                            ref: ref,
                          );
                        },
                      );
                    } finally {
                      CanvasHtmlOverlayController.instance.resume();
                    }
                  },
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white70,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (ver) async {
        final path = state.selectedCanvasPath;
        if (path == null) return;
        try {
          // Keep suspended until preview loads to avoid accidental clicks
          CanvasHtmlOverlayController.instance.suspend();
          await ref
              .read(playgroundProvider)
              .enterCanvasVersionPreview(path: path, versionNumber: ver);
        } finally {
          CanvasHtmlOverlayController.instance.resume();
        }
      },
    );
  }
}

class _InlineDiffModal extends StatelessWidget {
  final String path;
  final int versionNumber;
  final String oldContent;
  final String latestContent;
  final WidgetRef ref;
  const _InlineDiffModal({
    required this.path,
    required this.versionNumber,
    required this.oldContent,
    required this.latestContent,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final narrow = c.maxWidth < 720;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text(
                        'Changes · v$versionNumber',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await ref
                              .read(playgroundProvider)
                              .enterCanvasVersionPreview(
                                path: path,
                                versionNumber: versionNumber,
                              );
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('Preview'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await ref
                              .read(playgroundProvider)
                              .restoreCanvasVersion(
                                path: path,
                                versionNumber: versionNumber,
                              );
                          if (ok && context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Version restored')),
                            );
                          }
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('Restore'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 420,
                  child:
                      narrow
                          ? DiffPreview(
                            path: path,
                            oldContent: oldContent,
                            newContent: latestContent,
                            collapsible: false,
                            scrollable: true,
                          )
                          : SideBySideDiff(
                            path: path,
                            oldContent: oldContent,
                            newContent: latestContent,
                            showHeader: true,
                          ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewVersionBanner extends StatelessWidget {
  final WidgetRef ref;
  const _PreviewVersionBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final ver = state.previewVersionNumber;
    final path = state.selectedCanvasPath;
    if (ver == null || path == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9A7).withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFE9A7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Previewing historical version v$ver. You can run/inspect it. This is temporary until you restore or exit preview.',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed:
                () => ref.read(playgroundProvider).exitCanvasVersionPreview(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Text('Back to latest'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () async {
              final ok = await ref
                  .read(playgroundProvider)
                  .restoreCanvasVersion(path: path, versionNumber: ver);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Version restored')),
                );
                await ref.read(playgroundProvider).exitCanvasVersionPreview();
              }
            },
            icon: const Icon(Icons.history),
            label: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}

class _PreviewNotSupported extends StatelessWidget {
  const _PreviewNotSupported();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.visibility_off_outlined,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Oops, we can't preview this code right now",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _WebPreview extends StatefulWidget {
  final String content; // HTML with inline CSS/JS
  const _WebPreview({required this.content});
  @override
  State<_WebPreview> createState() => _WebPreviewState();
}

class _WebPreviewState extends State<_WebPreview> {
  WebViewController? _controller;

  String _toDataUrl(String html) {
    final src = _wrapIfNeeded(html);
    final uri = Uri.dataFromString(
      src,
      mimeType: 'text/html',
      encoding: const Utf8Codec(),
    );
    return uri.toString();
  }

  String _wrapIfNeeded(String content) {
    final lower = content.toLowerCase();
    final looksHtml = lower.contains('<html') || lower.contains('<!doctype');
    if (looksHtml) return content;
    final hasScriptTag = lower.contains('<script');
    final hasStyleTag = lower.contains('<style');
    // Heuristics: if no tags at all, decide if it's JS or CSS by simple patterns
    final hasTags = lower.contains('<');
    final maybeJs =
        content.contains('function ') ||
        content.contains('const ') ||
        content.contains('let ') ||
        content.contains('=>');
    final maybeCss =
        !maybeJs &&
        (content.contains('{') &&
            content.contains('}') &&
            content.contains(';'));
    final bodyInner = StringBuffer();
    if (hasScriptTag || hasStyleTag || hasTags) {
      bodyInner.write(content);
    } else if (maybeJs) {
      bodyInner.write('<script>\n');
      bodyInner.write(content);
      bodyInner.write('\n</script>');
    } else if (maybeCss) {
      bodyInner.write('<style>\n');
      bodyInner.write(content);
      bodyInner.write('\n</style>');
      bodyInner.write(
        '<div class="note">CSS loaded. Add HTML to see styled elements.</div>',
      );
    } else {
      // Plain text fallback
      bodyInner.write('<pre>');
      bodyInner.write(_escapeHtml(content));
      bodyInner.write('</pre>');
    }
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>html,body{margin:0;padding:16px;background:#0b0f19;color:#eaeaea;font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto} .note{opacity:.7;font-style:italic;margin-top:8px}</style>'
        '</head><body>'
        '${bodyInner.toString()}'
        '</body></html>';
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  void initState() {
    super.initState();
    try {
      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000));
      _controller = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller?.loadRequest(Uri.parse(_toDataUrl(widget.content)));
      });
    } catch (_) {
      // If webview unavailable on this platform, do nothing; UI fallback could be added.
    }
  }

  @override
  void didUpdateWidget(covariant _WebPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content && _controller != null) {
      _controller!.loadRequest(Uri.parse(_toDataUrl(widget.content)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use HtmlElementView-based preview on web
      return CanvasHtmlPreview(content: widget.content);
    }
    if (_controller == null) {
      // Fallback for platforms without WebView (e.g., Linux): offer to open in browser
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PreviewNotSupported(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.dataFromString(
                  _wrapIfNeeded(widget.content),
                  mimeType: 'text/html',
                  encoding: const Utf8Codec(),
                );
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open browser')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in browser'),
            ),
          ],
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
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
  final void Function(BuildContext pillContext, String url)?
  onHoverImageEnterUrl;
  // Bytes preview handlers (pre-upload)
  final void Function(Uint8List bytes, String title)? onOpenImageModalBytes;
  final void Function(BuildContext pillContext, Uint8List bytes)?
  onHoverImageEnterBytes;
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7F5AF0).withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: attachments chips + text field
              if (attachments.isNotEmpty)
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
                      for (int i = 0; i < attachments.length; i++)
                        Builder(
                          builder: (pillCtx) {
                            final att = attachments[i];
                            final name = att['file_name'] as String? ?? 'file';
                            final mime =
                                att['mime_type'] as String? ??
                                'application/octet-stream';
                            final isImage = mime.startsWith('image/');
                            final bytes = att['bytes'];
                            final signedUrl = att['signedUrl'] as String?;
                            final uri = att['uri'] as String?;
                            final bucketUrl = att['bucket_url'] as String?;
                            final url =
                                signedUrl?.isNotEmpty == true
                                    ? signedUrl
                                    : (uri?.isNotEmpty == true
                                        ? uri
                                        : (bucketUrl?.isNotEmpty == true
                                            ? bucketUrl
                                            : null));
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
                                    onTap: () => onRemoveAttachmentAt(i),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white60,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (isImage) {
                              // Pre-upload bytes hover/modal
                              if (bytes is Uint8List) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter:
                                      (_) => onHoverImageEnterBytes?.call(
                                        pillCtx,
                                        bytes,
                                      ),
                                  onExit: (_) => onHoverImageExit?.call(),
                                  child: GestureDetector(
                                    onTap:
                                        () => onOpenImageModalBytes?.call(
                                          bytes,
                                          name,
                                        ),
                                    child: pill,
                                  ),
                                );
                              }
                              // Post-upload URL hover/modal
                              if (url != null && url.isNotEmpty) {
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter:
                                      (_) => onHoverImageEnterUrl?.call(
                                        pillCtx,
                                        url,
                                      ),
                                  onExit: (_) => onHoverImageExit?.call(),
                                  child: GestureDetector(
                                    onTap:
                                        () => onOpenImageModalUrl?.call(
                                          url,
                                          name,
                                        ),
                                    child: pill,
                                  ),
                                );
                              }
                            }
                            return pill;
                          },
                        ),
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
                  Row(
                    children: [
                      // Enhanced attach button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed:
                              (sending || uploading) ? null : onPickFiles,
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: 'Attach files',
                        ),
                      ),
                    ],
                  ),
                  // Enhanced send button with gradient + wave loader
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (sending || uploading) ? null : onSend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(14),
                      ),
                      child:
                          (sending || uploading)
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: MiniWave(size: 22, color: Colors.white),
                              )
                              : const Icon(
                                Icons.rocket_launch,
                                color: Colors.white,
                                size: 20,
                              ),
                    ),
                  ),
                ],
              ),
              if (uploading)
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

  // Lightweight LRU cache to memoize parsed segments by content
  static final Map<String, List<_Segment>> _cache = <String, List<_Segment>>{};
  static const int _cacheCap = 64;
  static List<_Segment> _parseSegmentsCached(String input) {
    final existing = _cache.remove(input);
    if (existing != null) {
      _cache[input] = existing; // mark most-recent
      return existing;
    }
    final parsed = _parseSegments(input);
    _cache[input] = parsed;
    if (_cache.length > _cacheCap) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parseSegmentsCached(data);
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
