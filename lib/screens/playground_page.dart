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
import 'package:codemate/widgets/code_block_builder.dart';
import 'package:codemate/widgets/playground_code_block.dart';
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
  bool _historyOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  int _artifactPreviewIndex = 0;
  final GlobalKey _canvasTitleKey = GlobalKey();
  bool _hoveringCanvasTitle = false;
  // Composer image hover preview overlay
  OverlayEntry? _imageHoverOverlay;

  @override
  void dispose() {
    // Ensure any hover overlay is removed
    try {
      _imageHoverOverlay?.remove();
    } catch (_) {}
    _controller.dispose();
    _focusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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

  Widget _buildHistoryOverlay(BuildContext context) {
    if (!_historyOpen) return const SizedBox.shrink();
    final chats = ref.watch(playgroundProvider).chats;
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered =
        q.isEmpty
            ? chats
            : chats
                .where(
                  (c) =>
                      (c['title'] as String? ?? '').toLowerCase().contains(q),
                )
                .toList();

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 380,
      child: Material(
        color: const Color(0xFF17171C).withOpacity(0.98),
        elevation: 20,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        hintText: 'Search conversations',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => setState(() => _historyOpen = false),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child:
                  filtered.isEmpty
                      ? Center(
                        child: Text(
                          'No conversations',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = filtered[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white70,
                            ),
                            title: Text(
                              c['title'] ?? 'Untitled',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            onTap: () async {
                              await ref
                                  .read(playgroundProvider)
                                  .loadChat(c['id'] as String);
                              setState(() => _historyOpen = false);
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    // Enforce same restrictions as Agent chat: max 3 files, strict types
    // Allowed extensions
    const allowed = {
      'pdf',
      'png', 'jpg', 'jpeg', 'webp', 'gif',
      'txt', 'md', 'markdown', 'html', 'htm', 'xml',
    };

    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowed.toList(),
    );
    if (res == null) return;

    // Apply 3-file total limit
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

    // Queue files locally; upload happens on send. Store raw bytes for hover preview.
    final picked = res.files.take(remaining);
    int rejected = 0;
    for (final f in picked) {
      if (f.bytes == null) continue;
      final ext = f.extension?.toLowerCase() ?? f.name.split('.').last.toLowerCase();
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

  Future<void> _sendFeedback(String kind) async {
    final prov = ref.read(playgroundProvider);
    await prov.saveFeedback(kind: kind);
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

  Future<void> _showCanvasFilesMenu() async {
    final state = ref.read(playgroundProvider);
    if (state.canvasFiles.isEmpty) return;
    final ctx = _canvasTitleKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromLTWH(
        box.localToGlobal(Offset.zero).dx,
        box.localToGlobal(Offset.zero).dy + box.size.height,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: pos,
      color: const Color(0xFF1C1C22),
      items: [
        for (final f in state.canvasFiles)
          PopupMenuItem<String>(
            value: (f['path'] as String?) ?? '',
            child: Text(
              (f['path'] as String?) ?? 'file',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
      ],
    );
    if (selected != null && selected.isNotEmpty) {
      await ref.read(playgroundProvider).openCanvasFile(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playgroundProvider);
    final hasMessages = state.messages.isNotEmpty;
    final titleText =
        state.chatTitle?.isNotEmpty == true ? state.chatTitle! : 'Playground';
    return Scaffold(
      backgroundColor: const Color(0xFF121216),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            tooltip: 'History',
            onPressed: () async {
              await ref.read(playgroundProvider).fetchChats();
              setState(() => _historyOpen = true);
            },
            icon: const Icon(Icons.history, color: Colors.white),
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
      body: Row(
        children: [
          // Sidebar matches Home layout order
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
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BuildPage()),
                    ),
              ),
              PremiumSidebarItem(
                icon: Icons.school_rounded,
                label: 'Learn',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LearnPage()),
                    ),
              ),
            ],
            topPadding: 20,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showCanvas =
                    ref.watch(playgroundProvider).selectedCanvasPath != null;
                return Row(
                  children: [
                    Expanded(
                      flex: showCanvas ? 3 : 1,
                      child: Stack(
                        children: [
                          _buildGlow(),
                          if (!hasMessages)
                            _buildLanding(context)
                          else
                            _buildConversation(context),
                          _buildHistoryOverlay(context),
                        ],
                      ),
                    ),
                    if (showCanvas)
                      Container(
                        width: constraints.maxWidth * 0.35,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141419),
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.brush,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: MouseRegion(
                                      onEnter:
                                          (_) => setState(
                                            () => _hoveringCanvasTitle = true,
                                          ),
                                      onExit:
                                          (_) => setState(
                                            () => _hoveringCanvasTitle = false,
                                          ),
                                      child: GestureDetector(
                                        onTap: _showCanvasFilesMenu,
                                        child: Row(
                                          key: _canvasTitleKey,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.06),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.12),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _formatCanvasTitle(
                                                          ref
                                                                  .watch(
                                                                    playgroundProvider,
                                                                  )
                                                                  .selectedCanvasPath ??
                                                              '',
                                                        ),
                                                        style:
                                                            GoogleFonts.poppins(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(
                                                      Icons.expand_more,
                                                      color: Colors.white70,
                                                      size: 16,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close',
                                    onPressed:
                                        () =>
                                            ref
                                                .read(playgroundProvider)
                                                .closeCanvas(),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            Expanded(
                              child:
                                  ref.watch(playgroundProvider).loadingCanvas
                                      ? const Center(child: MiniWave(size: 28))
                                      : _CanvasPreview(
                                        content:
                                            ref
                                                .watch(playgroundProvider)
                                                .selectedCanvasContent ??
                                            '',
                                      ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final m = state.messages[index];
                final isUser = m.sender == 'user';
                final isLastAI =
                    !isUser &&
                    index ==
                        state.messages.lastIndexWhere(
                          (mm) => mm.sender == 'ai',
                        );
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
                              const Divider(color: Colors.white24, height: 1),
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
                );
              },
            ),
          ),
        ),
        // Bottom input, 50% width, identical to Home
        Align(
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

class _CanvasPreview extends StatelessWidget {
  final String content;
  const _CanvasPreview({required this.content});

  @override
  Widget build(BuildContext context) {
    final looksMarkdown = content.contains('# ') || content.contains('```');
    if (looksMarkdown) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Markdown(
          data: content,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: GoogleFonts.poppins(color: Colors.white, height: 1.6),
            code: GoogleFonts.robotoMono(
              backgroundColor: Colors.black.withOpacity(0.3),
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
            ),
          ),
          builders: {'pre': CodeBlockBuilder()},
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            content,
            style: GoogleFonts.robotoMono(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
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
