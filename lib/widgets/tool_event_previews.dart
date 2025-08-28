import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
// Flutter material import is required for clipboard functionality and UI widgets.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ToolEventPreviews extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final Future<String?> Function(String path) fetchCanvasPreview;
  final void Function(String path) openCanvas;
  const ToolEventPreviews({
    super.key,
    required this.events,
    required this.fetchCanvasPreview,
    required this.openCanvas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: events.map((e) => _buildEvent(context, e)).toList(),
    );
  }

  Widget _buildEvent(BuildContext context, Map<String, dynamic> e) {
    final name = e['name'] as String? ?? '';
    final result = e['result'];
    switch (name) {
      case 'analyze_document':
        return _AnalyzeDocumentPreview(result: result);
      case 'implement_feature_and_update_todo':
        return _CompositeImplementFeaturePreview(
          result: result,
          openCanvas: openCanvas,
        );
      case 'canvas_create_file':
        return _CanvasCreatePreview(
          result: result,
          fetchCanvasPreview: fetchCanvasPreview,
          openCanvas: openCanvas,
        );
      case 'canvas_update_file_content':
        return _CanvasCreatePreview(
          result: result,
          fetchCanvasPreview: fetchCanvasPreview,
          openCanvas: openCanvas,
        );
      case 'project_card_preview':
        return _ProjectCardPreview(result: result);
      case 'todo_list_create':
        return _TodoListPreview(result: result);
      case 'todo_list_check':
        return _TodoListPreview(result: result);
      case 'canvas_read_file':
        {
          String? label;
          if (result is Map && result['path'] != null) {
            label = _friendlyBaseName(result['path'].toString());
          }
          return _GenericToolHeader(name: 'Read', subtitle: label);
        }
      case 'canvas_read_file_by_id':
        {
          String? label;
          if (result is Map) {
            final p = result['path'];
            label = p == null ? null : _friendlyBaseName(p.toString());
          }
          return _GenericToolHeader(name: 'Read', subtitle: label);
        }
      case 'artifact_read':
        {
          String? titleLabel;
          if (result is Map) {
            final data = result['data'];
            if (data is Map) {
              final n = (data['name'] as String?) ?? (data['title'] as String?);
              if (n != null && n.isNotEmpty) titleLabel = _friendlyBaseName(n);
            }
          }
          return _GenericToolHeader(name: 'Searched', subtitle: titleLabel);
        }
      default:
        return _GenericToolPreview(name: name, result: result);
    }
  }
}

String _friendlyBaseName(String raw) {
  var r = raw.trim();
  if (r.isEmpty) return r;
  final slash = r.lastIndexOf('/');
  if (slash >= 0 && slash < r.length - 1) {
    r = r.substring(slash + 1);
  }
  final dot = r.lastIndexOf('.');
  if (dot > 0) r = r.substring(0, dot);
  r = r.replaceAll('_', ' ').replaceAll('-', ' ');
  return r;
}

class _CanvasCreatePreview extends StatefulWidget {
  final dynamic result;
  final Future<String?> Function(String path) fetchCanvasPreview;
  final void Function(String path) openCanvas;
  const _CanvasCreatePreview({
    required this.result,
    required this.fetchCanvasPreview,
    required this.openCanvas,
  });

  @override
  State<_CanvasCreatePreview> createState() => _CanvasCreatePreviewState();
}

class _CanvasCreatePreviewState extends State<_CanvasCreatePreview> {
  String? _preview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = (widget.result is Map<String, dynamic>) ? widget.result as Map<String, dynamic> : {};
    final status = map['status'] as String?;
    if (status == 'error') {
      setState(() { _error = map['message']?.toString(); _loading = false; });
      return;
    }
    final inlineContent = map['content'] as String?;
    final path = map['path'] as String?;
    if ((inlineContent != null && inlineContent.isNotEmpty)) {
      setState(() { _preview = inlineContent; _loading = false; });
      return;
    }
    if (path != null && path.isNotEmpty) {
      final content = await widget.fetchCanvasPreview(path);
      if (!mounted) return;
      setState(() { _preview = content; _loading = false; });
      return;
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final map = (widget.result is Map<String, dynamic>) ? widget.result as Map<String, dynamic> : {};
    final path = map['path'] as String?;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151824), Color(0xFF111320), Color(0xFF0E1018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (path != null)
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    path,
                    style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () { if (path.isNotEmpty) widget.openCanvas(path); },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Canvas'),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            _ErrorCallout(message: _error!),
          ] else
          if (_loading)
            Text(
              'Loading preview…',
              style: GoogleFonts.poppins(color: Colors.white60),
            )
          else if ((_preview ?? '').isEmpty)
            Text(
              'No content yet',
              style: GoogleFonts.poppins(color: Colors.white60),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _preview!.split('\n').take(8).join('\n'),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _PrimaryButton(
                        icon: Icons.open_in_new,
                        label: 'Open in Canvas',
                        onPressed: path == null ? null : () => widget.openCanvas(path),
                      ),
                      const Spacer(),
                      _GhostButton(
                        icon: Icons.unfold_more,
                        label: 'Expand',
                        onPressed: () { _showExpanded(context, _preview!); },
                      ),
                      const SizedBox(width: 8),
                      _GhostButton(
                        icon: Icons.copy_all,
                        label: 'Copy',
                        onPressed: () { Clipboard.setData(ClipboardData(text: _preview!)); },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showExpanded(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F1420),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 920, minHeight: 200),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Canvas Preview', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _GhostButton(
                    icon: Icons.copy_all,
                    label: 'Copy',
                    onPressed: () { Clipboard.setData(ClipboardData(text: code)); },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Text(
                    code,
                    style: GoogleFonts.jetBrainsMono(color: Colors.white70, height: 1.55),
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

class _ProjectCardPreview extends StatefulWidget {
  final dynamic result;
  const _ProjectCardPreview({required this.result});

  @override
  State<_ProjectCardPreview> createState() => _ProjectCardPreviewState();
}

class _ProjectCardPreviewState extends State<_ProjectCardPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card =
        (widget.result is Map<String, dynamic>)
            ? widget.result['card'] as Map<String, dynamic>?
            : null;
    if (card == null) return const SizedBox.shrink();
    final name = card['name'] as String? ?? 'Untitled';
    final summary = card['summary'] as String? ?? '';
    final keyFeatures =
        (card['key_features'] as List?)?.map((e) => e.toString()).toList() ??
        const [];
    final canImplement = (card['can_implement_in_canvas'] as bool?) ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF151824), Color(0xFF111320), Color(0xFF0E1018)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                top: 24,
                right: 24,
                child: IgnorePointer(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0x557F5AF0), Color(0x003B1E8E)],
                        radius: 0.9,
                        center: Alignment(0.5, -0.1),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (keyFeatures.isNotEmpty) ...[
                    Text(
                      'Key features',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...keyFeatures.map(
                      (f) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              style: GoogleFonts.poppins(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7F5AF0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          if (!canImplement) {
                            showDialog(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF191A20),
                                    title: const Text(
                                      'Start Project',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: const Text(
                                      'This project seems a little advanced. Would you like to work on it as a standalone project?',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.4,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF7F5AF0,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                        },
                                        child: const Text('Start Project'),
                                      ),
                                    ],
                                  ),
                            );
                          } else {
                            // Placeholder for canvas build flow
                          }
                        },
                        child: Text(
                          canImplement ? 'Start building' : 'Start Project',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodoListPreview extends StatelessWidget {
  final dynamic result;
  const _TodoListPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final todo =
        (map['todo'] is Map<String, dynamic>)
            ? map['todo'] as Map<String, dynamic>
            : null;
    if (todo == null) return const SizedBox.shrink();
    final title = todo['title'] as String? ?? 'To-Do';
    final tasksRaw = (todo['tasks'] as List?) ?? const [];
    final tasks = tasksRaw.map((e) => e as Map<String, dynamic>).toList();
    final notes = map['notes'] as String?;
    final total = tasks.length;
    final done = tasks.where((t) => (t['done'] as bool?) == true).length;

    final visible = tasks.take(8).toList();
    final remaining = total - visible.length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1420), Color(0xFF0C1018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rtl,
                color: Color(0xFF7F5AF0),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...visible.map((t) {
            final isDone = (t['done'] as bool?) ?? false;
            final label = (t['title'] as String?) ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? const Color(0xFF2CB67D) : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: isDone ? Colors.white60 : Colors.white70,
                        decoration:
                            isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+$remaining more',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ),
          if ((notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, color: Colors.white70, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes!,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$done of $total completed',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2CB67D).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2CB67D).withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  '${((total == 0) ? 0 : (done / total * 100)).round()}%',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF2CB67D),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenericToolPreview extends StatelessWidget {
  final String name;
  final dynamic result;
  const _GenericToolPreview({required this.name, required this.result});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.extension, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                name,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            const JsonEncoder.withIndent('  ').convert(result),
            style: GoogleFonts.robotoMono(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GenericToolHeader extends StatelessWidget {
  final String name;
  final String? subtitle;
  const _GenericToolHeader({required this.name, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              subtitle == null ? name : '$name · $subtitle',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzeDocumentPreview extends StatelessWidget {
  final dynamic result;
  const _AnalyzeDocumentPreview({required this.result});
  @override
  Widget build(BuildContext context) {
    final map = (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
  final rawStatus = (map['status'] as String?) ?? 'unknown';
  final status = rawStatus.toLowerCase();
    final mime = (map['mime_type'] as String?) ?? (map['mime'] as String?) ?? '';
    final message = (map['message'] as String?) ?? '';
  final bool isOk = status == 'success';
  final bool isErr = status == 'error' || (status == 'unknown' && message.isNotEmpty);
  final bool isProcessing = !isOk && !isErr && (status == 'processing' || status == 'in_progress' || status == 'pending' || status == 'unknown');

  final Color color = isOk
    ? const Color(0xFF2CB67D)
    : (isProcessing ? const Color(0xFFE3B341) : const Color(0xFFE45858));
  final Color bg = isOk
    ? const Color(0x332CB67D)
    : (isProcessing ? const Color(0x33E3B341) : const Color(0x33E45858));
  final Color border = isOk
    ? const Color(0x552CB67D)
    : (isProcessing ? const Color(0x55E3B341) : const Color(0x55E45858));

  final String label = isOk
    ? ((mime.isNotEmpty ? mime.split('/').first.toUpperCase() : 'FILE') + ' analyzed')
    : (isProcessing
      ? ((mime.isNotEmpty ? mime.split('/').first.toUpperCase() : 'FILE') + ' processing…')
      : 'Analysis failed');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(isOk ? Icons.analytics_outlined : (isProcessing ? Icons.hourglass_top_outlined : Icons.error_outline), color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'analyze_document',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Container(
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    label,
                    style: GoogleFonts.robotoMono(color: color, fontSize: 12),
                  ),
                ),
                if (!isOk && !isProcessing && message.isNotEmpty)
                  Flexible(
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositeImplementFeaturePreview extends StatelessWidget {
  final dynamic result;
  final void Function(String path) openCanvas;
  const _CompositeImplementFeaturePreview({required this.result, required this.openCanvas});

  @override
  Widget build(BuildContext context) {
    final map = (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final taskTitle = (map['task_title'] as String?) ?? 'Task';
    final canvas = (map['canvas_file'] as Map<String, dynamic>?) ?? const {};
    final path = canvas['path'] as String?;
    final content = (canvas['content'] as String?) ?? '';
    final mode = (map['mode'] as String?) ?? 'updated';
    final headerLabel = mode == 'created' ? 'Created file' : 'Updated file';
    final status = (map['status'] as String?) ?? 'success';
    final message = (map['message'] as String?) ?? '';
    final availablePaths = (map['available_paths'] as List?)?.map((e) => e.toString()).toList() ?? const [];

    final boxDecoration = BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F1420), Color(0xFF0C1018)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    );

    return Container(
      decoration: boxDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'error' ? Icons.error_outline : Icons.task_alt,
                color: status == 'error' ? const Color(0xFFE45858) : const Color(0xFF2CB67D),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status == 'error' ? 'Action needed' : 'Completed: $taskTitle',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (status == 'error' && message.isNotEmpty) ...[
            _ErrorCallout(message: message),
            if (availablePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: availablePaths
                    .map((p) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(p, style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 12)),
                        ))
                    .toList(),
              ),
            ],
          ] else if (path != null)
            Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$headerLabel · $path',
                    style: GoogleFonts.poppins(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () { if (path.isNotEmpty) openCanvas(path); },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Canvas'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          if (status != 'error')
            Container(
              decoration: BoxDecoration(
                color: const Color(0x332CB67D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x552CB67D)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.split('\n').take(12).join('\n'),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  if (content.split('\n').length > 12) ...[
                    const SizedBox(height: 8),
                    Text(
                      '+ more lines',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorCallout extends StatelessWidget {
  final String message;
  const _ErrorCallout({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x33E45858),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55E45858)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE45858), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7F5AF0),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _GhostButton({required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }
}
