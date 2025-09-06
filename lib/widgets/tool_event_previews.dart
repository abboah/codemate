import 'dart:convert';
import 'package:flutter/services.dart';
// Flutter material import is required for clipboard functionality and UI widgets.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/widgets/fancy_loader.dart';

class ToolEventPreviews extends StatefulWidget {
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
  State<ToolEventPreviews> createState() => _ToolEventPreviewsState();
}

class _ToolEventPreviewsState extends State<ToolEventPreviews>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.events.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)),
        vsync: this,
      ),
    );

    _scaleAnimations =
        _controllers
            .map(
              (controller) => Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
              ),
            )
            .toList();

    _opacityAnimations =
        _controllers
            .map(
              (controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeOut),
              ),
            )
            .toList();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(ToolEventPreviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events.length != oldWidget.events.length) {
      // Dispose old controllers
      for (final controller in _controllers) {
        controller.dispose();
      }
      // Reinitialize with new length
      _initializeAnimations();
      _startAnimations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          widget.events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;

            if (index >= _controllers.length) return const SizedBox.shrink();

            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations[index].value,
                  child: Opacity(
                    opacity: _opacityAnimations[index].value,
                    child: _buildEvent(context, event),
                  ),
                );
              },
            );
          }).toList(),
    );
  }

  Widget _buildEvent(BuildContext context, Map<String, dynamic> e) {
    final name = e['name'] as String? ?? '';
    final result = e['result'];
    switch (name) {
      case 'lint_check':
        return _LintCheckPreview(result: result);
      case 'analyze_code':
        return _AnalyzeCodePreview(result: result);
      case 'canvas_list_versions':
        return _CanvasListVersionsPreview(
          result: result,
          openCanvas: widget.openCanvas,
        );
      case 'canvas_read_version':
        return _CanvasReadVersionPreview(result: result);
      case 'canvas_restore_version':
        return _CanvasRestoreVersionPreview(
          result: result,
          openCanvas: widget.openCanvas,
        );
      case 'analyze_document':
        return _AnalyzeDocumentPreview(result: result);
      case 'implement_feature_and_update_todo':
        return _CompositeImplementFeaturePreview(
          result: result,
          openCanvas: widget.openCanvas,
        );
      case 'create_file_from_template':
        return _TemplateCreatePreview(
          result: result,
          openCanvas: widget.openCanvas,
          fetchCanvasPreview: widget.fetchCanvasPreview,
        );
      case 'canvas_create_file':
        return _CanvasCreatePreview(
          result: result,
          fetchCanvasPreview: widget.fetchCanvasPreview,
          openCanvas: widget.openCanvas,
        );
      case 'canvas_update_file_content':
        return _CanvasCreatePreview(
          result: result,
          fetchCanvasPreview: widget.fetchCanvasPreview,
          openCanvas: widget.openCanvas,
        );
      case 'canvas_delete_file':
        return _CanvasDeletePreview(result: result);
      case 'canvas_search':
        return _CanvasSearchPreview(result: result);
      case 'generate_image':
      case 'enhance_image':
        return _ImageToolPreview(result: result);
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

class _AnalyzeCodePreview extends StatelessWidget {
  final dynamic result;
  const _AnalyzeCodePreview({required this.result});

  bool get _processing {
    final r = result;
    if (r == null) return true;
    if (r is Map) {
      final status = (r['status']?.toString().toLowerCase() ?? '');
      return status.isEmpty ||
          status == 'processing' ||
          status == 'in_progress' ||
          status == 'pending' ||
          status == 'unknown';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: MiniWave(size: 16)),
            const SizedBox(width: 8),
            Text(
              'Analyzing code…',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2CB67D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Code analyzed',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LintCheckPreview extends StatefulWidget {
  final dynamic result;
  const _LintCheckPreview({required this.result});

  @override
  State<_LintCheckPreview> createState() => _LintCheckPreviewState();
}

class _LintCheckPreviewState extends State<_LintCheckPreview> {
  bool _expanded = false;

  bool get _processing {
    final r = widget.result;
    if (r == null) return true;
    if (r is Map) {
      final status = (r['status']?.toString().toLowerCase() ?? '');
      final hasIssues = r['issues'] is List && (r['issues'] as List).isNotEmpty;
      final hasCount = r['issue_count'] is num;
      final processing =
          status.isEmpty ||
          status == 'processing' ||
          status == 'in_progress' ||
          status == 'pending' ||
          status == 'unknown';
      return processing && !hasIssues && !hasCount;
    }
    return false;
  }

  int _issueCount(Map<String, dynamic> map) {
    final c = map['issue_count'];
    if (c is num) return c.toInt();
    final issues = map['issues'];
    if (issues is List) return issues.length;
    return 0;
  }

  List<Map<String, dynamic>> _issues(Map<String, dynamic> map) {
    final raw = map['issues'];
    if (raw is List) {
      return raw.map<Map<String, dynamic>>((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v));
        }
        return <String, dynamic>{'message': e.toString()};
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    if (_processing) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: MiniWave(size: 16)),
            const SizedBox(width: 8),
            Text(
              'Checking code…',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final map =
        (widget.result is Map)
            ? (widget.result as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
    final count = _issueCount(map);
    final issues = _issues(map);
    final hasIssues = count > 0;
    final icon =
        hasIssues
            ? const Icon(
              Icons.close_rounded,
              color: Color(0xFFE5484D),
              size: 18,
            )
            : const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2CB67D),
              size: 18,
            );
    final title =
        hasIssues ? 'Code lints: $count issues found' : 'No lints found';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap:
                hasIssues ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasIssues)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded && hasIssues)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _LintIssuesList(issues: issues),
            ),
        ],
      ),
    );
  }
}

class _LintIssuesList extends StatelessWidget {
  final List<Map<String, dynamic>> issues;
  const _LintIssuesList({required this.issues});

  Color _sevColor(String sev) {
    switch (sev.toLowerCase()) {
      case 'error':
      case 'high':
      case 'blocker':
        return const Color(0xFFE5484D);
      case 'warning':
      case 'medium':
        return const Color(0xFFF5D90A);
      case 'info':
      case 'low':
      default:
        return const Color(0xFF2CB67D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = issues.take(50).toList();
    final remaining = issues.length - visible.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in visible)
          _LintIssueTile(
            issue: i,
            color: _sevColor(
              (i['severity'] ?? i['level'] ?? 'warning').toString(),
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '+$remaining more…',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _LintIssueTile extends StatelessWidget {
  final Map<String, dynamic> issue;
  final Color color;
  const _LintIssueTile({required this.issue, required this.color});

  String _fileLine(Map<String, dynamic> i) {
    final path = (i['path'] ?? i['file'] ?? i['source'] ?? '').toString();
    final line = (i['line'] ?? i['row'] ?? i['lineNumber'] ?? '').toString();
    if (path.isEmpty && line.isEmpty) return '';
    return [if (path.isNotEmpty) path, if (line.isNotEmpty) 'L$line'].join(':');
  }

  @override
  Widget build(BuildContext context) {
    final msg =
        (issue['message'] ??
                issue['reason'] ??
                issue['description'] ??
                issue['msg'] ??
                '')
            .toString()
            .trim();
    final sev = (issue['severity'] ?? issue['level'] ?? '').toString();
    final fileLine = _fileLine(issue);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg.isNotEmpty ? msg : '(no message)',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (fileLine.isNotEmpty)
                Expanded(
                  child: Text(
                    fileLine,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.robotoMono(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (sev.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  sev.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
    final map =
        (widget.result is Map<String, dynamic>)
            ? widget.result as Map<String, dynamic>
            : {};
    final status = map['status'] as String?;
    if (status == 'error') {
      setState(() {
        _error = map['message']?.toString();
        _loading = false;
      });
      return;
    }
    final inlineContent = map['content'] as String?;
    final path = map['path'] as String?;
    if ((inlineContent != null && inlineContent.isNotEmpty)) {
      setState(() {
        _preview = inlineContent;
        _loading = false;
      });
      return;
    }
    if (path != null && path.isNotEmpty) {
      final content = await widget.fetchCanvasPreview(path);
      if (!mounted) return;
      setState(() {
        _preview = content;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final map =
        (widget.result is Map<String, dynamic>)
            ? widget.result as Map<String, dynamic>
            : {};
    final path = map['path'] as String?;
    // Prefer description metadata if available
    final description = (map['description'] as String?)?.trim();
    final fileName = path != null ? _friendlyBaseName(path) : 'Canvas File';
    final headerTitle =
        (description != null && description.isNotEmpty)
            ? description
            : fileName;
    // Determine extension-based type label for footer
    String? footerType;
    if (path != null) {
      final lower = path.toLowerCase();
      if (lower.endsWith('.md') || lower.endsWith('.markdown'))
        footerType = 'Markdown file';
      else if (lower.endsWith('.txt'))
        footerType = 'Text file';
      else if (lower.endsWith('.html') || lower.endsWith('.htm'))
        footerType = 'HTML file';
      else if (lower.endsWith('.css'))
        footerType = 'CSS file';
      else if (lower.endsWith('.js'))
        footerType = 'JavaScript file';
      else if (lower.endsWith('.ts'))
        footerType = 'TypeScript file';
      else if (lower.endsWith('.json'))
        footerType = 'JSON file';
      else if (lower.endsWith('.dart'))
        footerType = 'Dart file';
      else if (lower.endsWith('.py'))
        footerType = 'Python file';
      else if (lower.endsWith('.java'))
        footerType = 'Java file';
      else if (lower.endsWith('.c'))
        footerType = 'C file';
      else if (lower.endsWith('.cpp') ||
          lower.endsWith('.cc') ||
          lower.endsWith('.cxx'))
        footerType = 'C++ file';
      else if (lower.endsWith('.rs'))
        footerType = 'Rust file';
      else if (lower.endsWith('.go'))
        footerType = 'Go file';
      else if (lower.endsWith('.kt') || lower.endsWith('.kts'))
        footerType = 'Kotlin file';
      else if (lower.endsWith('.swift'))
        footerType = 'Swift file';
      else
        footerType = null;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151824), Color(0xFF111320), Color(0xFF0E1018)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with file info
          if (path != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                      Icons.code,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          path,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Content preview
          if (_error != null) ...[
            _ErrorCallout(message: _error!),
          ] else if (_loading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: MiniWave(size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Loading preview…',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else if ((_preview ?? '').isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No content preview available',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _preview!.split('\n').take(6).join('\n'),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (_preview!.split('\n').length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... ${_preview!.split('\n').length - 6} more lines',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Footer label (extension-based type) + action buttons
          Row(
            children: [
              if (footerType != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    footerType,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (path != null && path.isNotEmpty)
                Expanded(
                  child: _PrimaryButton(
                    icon: Icons.open_in_new,
                    label: 'Open in Canvas',
                    onPressed: () => widget.openCanvas(path),
                  ),
                ),
              if ((_preview ?? '').isNotEmpty) ...[
                if (path != null && path.isNotEmpty) const SizedBox(width: 8),
                _GhostButton(
                  icon: Icons.unfold_more,
                  label: 'Expand',
                  onPressed: () => _showExpanded(context, _preview!),
                ),
                const SizedBox(width: 4),
                _GhostButton(
                  icon: Icons.copy_all,
                  label: 'Copy',
                  onPressed:
                      () => Clipboard.setData(ClipboardData(text: _preview!)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showExpanded(BuildContext context, String code) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1A1D29),
                    Color(0xFF151824),
                    Color(0xFF0F1420),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.code,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Canvas Preview',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          _GhostButton(
                            icon: Icons.copy_all,
                            label: 'Copy All',
                            onPressed:
                                () => Clipboard.setData(
                                  ClipboardData(text: code),
                                ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                              size: 20,
                            ),
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

                    // Content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            code,
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
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
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1D29),
                const Color(0xFF151821),
                const Color(0xFF121319),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              // Animated gradient background effect
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(
                                const Color(0x556366F1),
                                const Color(0x558B5CF6),
                                _controller.value,
                              ) ??
                              const Color(0x556366F1),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                        center: const Alignment(0.3, -0.2),
                      ),
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project header with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6366F1),
                              const Color(0xFF8B5CF6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Project Idea',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Project description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      summary,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Key features
                  if (keyFeatures.isNotEmpty) ...[
                    Text(
                      'Key Features',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children:
                            keyFeatures
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          entry.key == keyFeatures.length - 1
                                              ? 0
                                              : 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white.withOpacity(
                                                0.8,
                                              ),
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1),
                            const Color(0xFF8B5CF6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      'Start Project',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    content: Text(
                                      'This project seems a little advanced. Would you like to work on it as a standalone project?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        height: 1.4,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF6366F1,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed:
                                            () => Navigator.of(ctx).pop(),
                                        child: Text(
                                          'Start Project',
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ),
                                    ],
                                  ),
                            );
                          } else {
                            // Placeholder for canvas build flow
                          }
                        },
                        icon: Icon(
                          canImplement ? Icons.play_arrow : Icons.rocket_launch,
                          size: 18,
                        ),
                        label: Text(
                          canImplement ? 'Start Building' : 'Start Project',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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
    final Map<String, dynamic> map =
        (result is Map<String, dynamic>)
            ? result as Map<String, dynamic>
            : <String, dynamic>{};
    final rawStatus = (map['status'] as String?) ?? 'unknown';
    final status = rawStatus.toLowerCase();
    final mime =
        (map['mime_type'] as String?) ?? (map['mime'] as String?) ?? '';
    final message = (map['message'] as String?) ?? '';

    final bool isOk = status == 'success';
    final bool isErr =
        status == 'error' || (status == 'unknown' && message.isNotEmpty);
    final bool isProcessing =
        !isOk &&
        !isErr &&
        (status == 'processing' ||
            status == 'in_progress' ||
            status == 'pending' ||
            status == 'unknown');

    final String fileType =
        mime.isNotEmpty ? mime.split('/').first.toUpperCase() : 'FILE';
    final String label =
        isOk
            ? '$fileType analyzed'
            : (isProcessing ? '$fileType processing…' : 'Analysis failed');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          // Icon or animation based on status
          if (isProcessing)
            const SizedBox(width: 18, height: 18, child: MiniWave(size: 18))
          else if (isOk)
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF2CB67D),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 12),
            )
          else
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFE45858),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.90),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (message.isNotEmpty && isErr)
            Tooltip(
              message: message,
              child: Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.6),
                size: 16,
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
  const _CompositeImplementFeaturePreview({
    required this.result,
    required this.openCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final taskTitle = (map['task_title'] as String?) ?? 'Task';
    final canvas = (map['canvas_file'] as Map<String, dynamic>?) ?? const {};
    final path = canvas['path'] as String?;
    final content = (canvas['content'] as String?) ?? '';
    final mode = (map['mode'] as String?) ?? 'updated';
    final headerLabel = mode == 'created' ? 'Created file' : 'Updated file';
    final status = (map['status'] as String?) ?? 'success';
    final message = (map['message'] as String?) ?? '';
    final availablePaths =
        (map['available_paths'] as List?)?.map((e) => e.toString()).toList() ??
        const [];

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
                color:
                    status == 'error'
                        ? const Color(0xFFE45858)
                        : const Color(0xFF2CB67D),
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
                children:
                    availablePaths
                        .map(
                          (p) => Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              p,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ] else if (path != null)
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$headerLabel · $path',
                    style: GoogleFonts.poppins(color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7F5AF0), Color(0xFF9D4EDD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7F5AF0).withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (path.isNotEmpty) openCanvas(path);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open in Canvas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
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
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
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
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
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

// ===== New Previews for Versioning and Additional Tools =====

class _CanvasListVersionsPreview extends StatelessWidget {
  final dynamic result;
  final void Function(String path) openCanvas;
  const _CanvasListVersionsPreview({
    required this.result,
    required this.openCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final status = (map['status'] as String?) ?? 'unknown';
    final path = (map['path'] as String?) ?? '';
    final versions = (map['versions'] as List?)?.cast<Map>() ?? const [];
    final fileName = path.isNotEmpty ? _friendlyBaseName(path) : 'Canvas';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111520), Color(0xFF0E1220)],
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
              const Icon(Icons.history, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Versions • $fileName',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (path.isNotEmpty)
                _GhostButton(
                  icon: Icons.open_in_new,
                  label: 'Open',
                  onPressed: () => openCanvas(path),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (status == 'error')
            _ErrorCallout(
              message: (map['message'] as String?) ?? 'Failed to list versions',
            )
          else if (versions.isEmpty)
            Text(
              'No versions found',
              style: GoogleFonts.poppins(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  versions.map((v) {
                    final ver = v['version_number']?.toString() ?? '?';
                    final desc = (v['description'] as String?) ?? '';
                    final createdAt = (v['created_at'] as String?) ?? '';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF7F5AF0,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v$ver',
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFFB9A6FF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (createdAt.isNotEmpty)
                                Text(
                                  createdAt,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          if (desc.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 220,
                              child: Text(
                                desc,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CanvasReadVersionPreview extends StatelessWidget {
  final dynamic result;
  const _CanvasReadVersionPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final status = (map['status'] as String?) ?? 'unknown';
    if (status == 'error') {
      return _ErrorCallout(
        message: (map['message'] as String?) ?? 'Failed to read version',
      );
    }
    final path = (map['path'] as String?) ?? '';
    final ver = map['version_number']?.toString() ?? '?';
    final desc = (map['description'] as String?) ?? '';
    final createdAt = (map['created_at'] as String?) ?? '';
    final content = (map['content'] as String?) ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF121726), Color(0xFF0E1320)],
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
                Icons.article_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Version v$ver • ${_friendlyBaseName(path)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (desc.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc, style: GoogleFonts.poppins(color: Colors.white70)),
          ],
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SelectableText(
                content.isEmpty ? '// no content' : content,
                style: GoogleFonts.robotoMono(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasRestoreVersionPreview extends StatelessWidget {
  final dynamic result;
  final void Function(String path) openCanvas;
  const _CanvasRestoreVersionPreview({
    required this.result,
    required this.openCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final status = (map['status'] as String?) ?? 'unknown';
    final path = (map['path'] as String?) ?? '';
    final ver = map['version_number']?.toString() ?? '?';
    final newVer = map['new_version_number']?.toString();
    final message = (map['message'] as String?) ?? '';

    final ok = status == 'success';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10202A), Color(0xFF0D1622)],
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
              Icon(
                ok ? Icons.restore : Icons.restore_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok ? 'Restored v$ver → current' : 'Restore version',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (path.isNotEmpty)
                _GhostButton(
                  icon: Icons.open_in_new,
                  label: 'Open',
                  onPressed: () => openCanvas(path),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (ok)
            Text(
              newVer != null
                  ? 'New head is v$newVer (restored from v$ver)'
                  : 'Canvas restored to v$ver',
              style: GoogleFonts.poppins(color: Colors.white70),
            )
          else if (message.isNotEmpty)
            _ErrorCallout(message: message)
          else
            Text(
              'Unknown restore result',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

class _TemplateCreatePreview extends StatefulWidget {
  final dynamic result;
  final void Function(String path) openCanvas;
  final Future<String?> Function(String path) fetchCanvasPreview;
  const _TemplateCreatePreview({
    required this.result,
    required this.openCanvas,
    required this.fetchCanvasPreview,
  });

  @override
  State<_TemplateCreatePreview> createState() => _TemplateCreatePreviewState();
}

class _TemplateCreatePreviewState extends State<_TemplateCreatePreview> {
  String? _preview;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> map =
        (widget.result is Map<String, dynamic>)
            ? widget.result as Map<String, dynamic>
            : <String, dynamic>{};
    final path = (map['path'] as String?) ?? '';
    if (path.isNotEmpty) {
      _loading = true;
      widget.fetchCanvasPreview(path).then((c) {
        if (!mounted) return;
        setState(() {
          _preview = c;
          _loading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> map =
        (widget.result is Map<String, dynamic>)
            ? widget.result as Map<String, dynamic>
            : <String, dynamic>{};
    final status = (map['status'] as String?) ?? 'unknown';
    final path = (map['path'] as String?) ?? '';
    final desc = (map['description'] as String?) ?? '';

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
              const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Created from template • ${path.isEmpty ? 'Canvas' : _friendlyBaseName(path)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (path.isNotEmpty)
                _GhostButton(
                  icon: Icons.open_in_new,
                  label: 'Open',
                  onPressed: () => widget.openCanvas(path),
                ),
            ],
          ),
          if (status == 'error') ...[
            const SizedBox(height: 8),
            _ErrorCallout(
              message:
                  (map['message'] as String?) ??
                  'Failed to create from template',
            ),
          ] else ...[
            if (desc.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: GoogleFonts.poppins(color: Colors.white70)),
            ],
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              child:
                  _loading
                      ? Row(
                        children: [
                          const MiniWave(size: 14),
                          const SizedBox(width: 10),
                          Text(
                            'Loading preview…',
                            style: GoogleFonts.poppins(color: Colors.white54),
                          ),
                        ],
                      )
                      : SingleChildScrollView(
                        child: SelectableText(
                          (_preview ?? '').isEmpty
                              ? '// preview unavailable'
                              : _preview!,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CanvasDeletePreview extends StatelessWidget {
  final dynamic result;
  const _CanvasDeletePreview({required this.result});

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final status = (map['status'] as String?) ?? 'unknown';
    final path = (map['path'] as String?) ?? '';
    final message = (map['message'] as String?) ?? '';

    final ok = status == 'success';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            ok ? Icons.delete_outline : Icons.error_outline,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok
                  ? 'Deleted ${path.isEmpty ? 'canvas file' : _friendlyBaseName(path)}'
                  : (message.isEmpty ? 'Delete failed' : message),
              style: GoogleFonts.poppins(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasSearchPreview extends StatelessWidget {
  final dynamic result;
  const _CanvasSearchPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    final map =
        (result is Map<String, dynamic>) ? result as Map<String, dynamic> : {};
    final status = (map['status'] as String?) ?? 'unknown';
    final items =
        (map['results'] as List?) ?? (map['items'] as List?) ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Canvas search',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status == 'error')
            _ErrorCallout(
              message: (map['message'] as String?) ?? 'Search failed',
            )
          else if (items.isEmpty)
            Text(
              'No matches',
              style: GoogleFonts.poppins(color: Colors.white70),
            )
          else
            ...items.take(5).map((it) {
              final Map<String, dynamic> m =
                  (it is Map)
                      ? it.map((k, v) => MapEntry(k.toString(), v))
                      : <String, dynamic>{};
              final p = (m['path'] as String?) ?? '';
              final snip =
                  (m['snippet'] as String?) ?? (m['excerpt'] as String?) ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p,
                        style: GoogleFonts.robotoMono(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (snip.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          snip,
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ImageToolPreview extends StatelessWidget {
  final dynamic result;
  const _ImageToolPreview({required this.result});

  String? _pickUrl(Map<String, dynamic> map) {
    return (map['url'] as String?) ??
        (map['signedUrl'] as String?) ??
        (map['publicUrl'] as String?) ??
        (map['image_url'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> map =
        (result is Map)
            ? (result as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
    final status = (map['status'] as String?) ?? 'unknown';
    final img = _pickUrl(map);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF141725), Color(0xFF0E1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                'Image',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status == 'error')
            _ErrorCallout(
              message: (map['message'] as String?) ?? 'Image tool failed',
            )
          else if (img != null && img.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(img, height: 160, fit: BoxFit.cover),
            )
          else
            Text(
              'Image ready (no preview url)',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
