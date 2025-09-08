import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:codemate/widgets/agent_tool_event_previews.dart';

/// Lightweight overlay list for hashtag (#) artifact mentions.
/// Fetches recent artifacts for the project (optionally scoped to chat)
/// and filters client-side by [query].
class ArtifactMentionOverlay extends StatefulWidget {
  final String projectId;
  final String? chatId;
  final String query;
  final bool visible;
  final void Function(Map<String, dynamic> row) onSelect;

  const ArtifactMentionOverlay({
    super.key,
    required this.projectId,
    required this.chatId,
    required this.query,
    required this.visible,
    required this.onSelect,
  });

  @override
  State<ArtifactMentionOverlay> createState() => _ArtifactMentionOverlayState();
}

class _ArtifactMentionOverlayState extends State<ArtifactMentionOverlay> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  OverlayEntry? _hoverOverlay;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant ArtifactMentionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch when project/chat scope changes (not for every keystroke)
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.chatId != widget.chatId) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supa = Supabase.instance.client;
      final table = supa.from('agent_artifacts');
      var query = table
          .select('id, artifact_type, data, key, last_modified, chat_id')
          .eq('project_id', widget.projectId)
          .order('last_modified', ascending: false);
      // If chatId provided, prefer those first by filtering later but keep all to allow fallback
      // Alternatively, you can query only chat artifacts when chatId is set.
      final res = await query;
      final list =
          (res as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filtered() {
    final q = widget.query.trim().toLowerCase();
    Iterable<Map<String, dynamic>> items = _rows;
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      // Prioritize artifacts from this chat by ordering them first
      final chatItems = items.where(
        (r) => (r['chat_id'] ?? '') == widget.chatId,
      );
      final otherItems = items.where(
        (r) => (r['chat_id'] ?? '') != widget.chatId,
      );
      items = [...chatItems, ...otherItems];
    }
    if (q.isEmpty) return items.take(8).toList();
    String getString(dynamic v) => v is String ? v : (v?.toString() ?? '');
    bool matches(Map<String, dynamic> r) {
      final key = getString(r['key']).toLowerCase();
      final type = getString(r['artifact_type']).toLowerCase();
      // Try to match a user-friendly label from data if present
      final data = r['data'];
      String dataTitle = '';
      if (data is Map) {
        dataTitle = getString(data['title']).toLowerCase();
      }
      return key.contains(q) || type.contains(q) || dataTitle.contains(q);
    }

    return items.where(matches).take(8).toList();
  }

  void _removeHoverOverlay() {
    try {
      _hoverOverlay?.remove();
    } catch (_) {}
    _hoverOverlay = null;
  }

  void _showHoverPreviewForRow(
    BuildContext itemContext,
    Map<String, dynamic> row,
  ) {
    _removeHoverOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final renderObject = itemContext.findRenderObject();
    if (renderObject is! RenderBox) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final screen = MediaQuery.of(context).size;

    const previewW = 380.0;
    double left = topLeft.dx + size.width + 8; // to the right of item
    double top = topLeft.dy;
    if (left + previewW > screen.width - 8) left = screen.width - 8 - previewW;
    final useBottomAnchor = topLeft.dy > screen.height * 0.6;

    final name = _artifactNameFromType(row['artifact_type'] as String?);
    final payload = _artifactResultPayload(row);

    _hoverOverlay = OverlayEntry(
      builder:
          (_) => Positioned(
            left: left,
            top: useBottomAnchor ? null : top,
            bottom: useBottomAnchor ? 8 : null,
            width: previewW,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  // Allow growth but keep within viewport
                  maxHeight: screen.height * 0.7,
                  minWidth: previewW,
                  maxWidth: previewW,
                ),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: AgentToolEventPreviews(
                    events: [
                      {'name': name, 'result': payload},
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
    overlay.insert(_hoverOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    if (_loading) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            _error!,
            style: GoogleFonts.poppins(color: Colors.redAccent),
          ),
        ),
      );
    }

    final rows = _filtered();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final label = _artifactLabel(row);
          return Builder(
            builder:
                (itemCtx) => MouseRegion(
                  onEnter: (_) => _showHoverPreviewForRow(itemCtx, row),
                  onExit: (_) => _removeHoverOverlay(),
                  child: InkWell(
                    onTap: () {
                      _removeHoverOverlay();
                      widget.onSelect(row);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storage_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          );
        },
      ),
    );
  }

  String _artifactLabel(Map<String, dynamic> row) {
    final key = row['key'] as String?;
    if (key != null && key.isNotEmpty) return key;
    final t = (row['artifact_type'] as String?) ?? 'artifact';
    final id = (row['id']?.toString() ?? '').toLowerCase();
    final short = id.isNotEmpty ? id.substring(0, id.length.clamp(0, 6)) : '';
    return short.isNotEmpty ? '$t#$short' : t;
  }

  String _artifactNameFromType(String? t) {
    switch (t) {
      case 'project_card_preview':
        return 'project_card_preview';
      case 'todo_list':
        return 'todo_list_create';
      default:
        return 'artifact_read';
    }
  }

  dynamic _artifactResultPayload(Map<String, dynamic> row) {
    final type = row['artifact_type'] as String?;
    final data = row['data'];
    switch (type) {
      case 'project_card_preview':
        return {'status': 'success', 'card': data};
      case 'todo_list':
        return {'status': 'success', 'todo': data, 'artifact_id': row['id']};
      default:
        return {'status': 'success', 'data': data, 'id': row['id']};
    }
  }

  @override
  void dispose() {
    _removeHoverOverlay();
    super.dispose();
  }
}
