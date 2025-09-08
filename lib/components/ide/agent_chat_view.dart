import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';

import 'package:codemate/components/ide/code_block_builder.dart';
import 'package:codemate/components/ide/inline_code_builder.dart';
import 'package:codemate/models/agent_chat_message.dart';
import 'package:codemate/providers/agent_chat_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:codemate/components/ide/diff_preview.dart';
import 'package:codemate/components/ide/edit_summary.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/components/ide/attach_code_dialog.dart';
import 'package:codemate/providers/diff_overlay_provider.dart';
import 'package:codemate/widgets/agent_tool_event_previews.dart';
import 'package:codemate/supabase_config.dart';
import 'package:codemate/utils/ndjson_stream.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';
import 'package:codemate/widgets/playground_code_block.dart';
// Duplicate import removed
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentChatView extends ConsumerStatefulWidget {
  final String projectId;
  const AgentChatView({super.key, required this.projectId});

  @override
  ConsumerState<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends ConsumerState<AgentChatView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();
  String? _activeChatId;
  String _selectedModel = 'gemini-2.5-flash';
  bool _askMode = false; // false = Agent, true = Ask

  List<AgentChatMessage> _localMessages = [];
  bool _isSendingNewChat = false;
  bool _isUploading = false; // show uploading indicator during send
  bool _autoScrollScheduled = false; // throttle auto-scroll scheduling
  bool _wasStreaming = false; // track stream-on -> stream-off transition

  // Composer image hover preview via global overlay
  OverlayEntry? _imageHoverOverlay;

  void _removeImageHoverOverlay() {
    try {
      _imageHoverOverlay?.remove();
    } catch (_) {}
    _imageHoverOverlay = null;
  }

  void _showImageHoverOverlayForPill(
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

  // Attachments state: list of maps { path, content, file_id }
  List<Map<String, dynamic>> _attachedFiles = [];

  // Mentions state
  bool _showMentions = false;
  String _mentionQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLatestChat();
    _controller.addListener(_handleTextChangedForMentions);
  }

  @override
  void dispose() {
    _removeImageHoverOverlay();
    _controller.removeListener(_handleTextChangedForMentions);
    _controller.dispose();
    _inputFocusNode.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestChat() {
    setState(() {
      _activeChatId = null;
      _localMessages = [];
    });
    return Future.value();
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();

    final attachmentsToSend = List<Map<String, dynamic>>.from(_attachedFiles);
    setState(() {
      _attachedFiles = [];
      _showMentions = false;
      _mentionQuery = '';
    });

    if (_activeChatId == null) {
      _startNewChat(text, attachmentsToSend);
    } else {
      // Upload any queued files first; keep user-visible text unchanged
      String promptText = text;
      List<Map<String, dynamic>> updatedAttachments = attachmentsToSend;
      final uploadables =
          attachmentsToSend
              .where(
                (a) =>
                    a['bytes'] is Uint8List &&
                    (a['type'] == 'img' || a['type'] == 'doc'),
              )
              .toList();
      if (uploadables.isNotEmpty) {
        setState(() => _isUploading = true);
        try {
          final supa = Supabase.instance.client;
          final List<Map<String, dynamic>> uploaded = [];
          for (final a in uploadables) {
            final bytes = a['bytes'] as Uint8List;
            final isImage = (a['type'] == 'img');
            final folder = isImage ? 'images' : 'docs';
            final safeName =
                (a['name'] as String?)?.replaceAll(
                  RegExp(r"[^A-Za-z0-9._-]"),
                  '_',
                ) ??
                'upload';
            final uid = supa.auth.currentUser?.id ?? 'anon';
            final key = '$uid/$folder/${const Uuid().v4()}_$safeName';
            final mime =
                (a['mime_type'] as String?) ?? _guessMimeFromName(safeName);
            await supa.storage
                .from('user-uploads')
                .uploadBinary(
                  key,
                  bytes,
                  fileOptions: FileOptions(contentType: mime),
                );
            final signed = await supa.storage
                .from('user-uploads')
                .createSignedUrl(key, 60 * 60);
            uploaded.add({
              'type': isImage ? 'img' : 'doc',
              'bucket_url': signed,
              'bucket_path': key,
              'name': a['name'] ?? safeName,
              'mime_type': mime,
              'size': (a['size'] as int?) ?? bytes.length,
            });
          }
          final others =
              attachmentsToSend
                  .where((a) => !(a['bytes'] is Uint8List))
                  .toList();
          updatedAttachments = [...others, ...uploaded];
          // Do not append URLs into the prompt to avoid bloating the user bubble.
          // The backend receives attachedFiles separately and will guide the model accordingly.
          promptText = text;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Attachment upload failed: $e')),
          );
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }

      ref
          .read(agentChatProvider(_activeChatId!).notifier)
          .sendMessage(
            text: promptText,
            model: _selectedModel,
            projectId: widget.projectId,
            attachedFiles: updatedAttachments,
            useAskHandler: _askMode,
            stream: true,
          );
    }
  }

  Future<void> _startNewChat(
    String text,
    List<Map<String, dynamic>> attachments,
  ) async {
    // Upload any queued files now (we delay uploads until send). Keep user text unchanged.
    String promptText = text;
    List<Map<String, dynamic>> updatedAttachments = attachments;
    final uploadables =
        attachments
            .where(
              (a) =>
                  a['bytes'] is Uint8List &&
                  (a['type'] == 'img' || a['type'] == 'doc'),
            )
            .toList();
    if (uploadables.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        final supa = Supabase.instance.client;
        final List<Map<String, dynamic>> uploaded = [];
        for (final a in uploadables) {
          final bytes = a['bytes'] as Uint8List;
          final isImage = (a['type'] == 'img');
          final folder = isImage ? 'images' : 'docs';
          final safeName =
              (a['name'] as String?)?.replaceAll(
                RegExp(r"[^A-Za-z0-9._-]"),
                '_',
              ) ??
              'upload';
          final uid = supa.auth.currentUser?.id ?? 'anon';
          final key = '$uid/$folder/${const Uuid().v4()}_$safeName';
          final mime =
              (a['mime_type'] as String?) ?? _guessMimeFromName(safeName);
          await supa.storage
              .from('user-uploads')
              .uploadBinary(
                key,
                bytes,
                fileOptions: FileOptions(contentType: mime),
              );
          // Signed URL for limited-time access
          final signed = await supa.storage
              .from('user-uploads')
              .createSignedUrl(key, 60 * 60);
          uploaded.add({
            'type': isImage ? 'img' : 'doc',
            'bucket_url': signed,
            'bucket_path': key,
            'name': a['name'] ?? safeName,
            'mime_type': mime,
            'size': (a['size'] as int?) ?? bytes.length,
          });
        }
        // Replace local upload placeholders in attachments with uploaded metadata
        final others =
            attachments.where((a) => !(a['bytes'] is Uint8List)).toList();
        updatedAttachments = [...others, ...uploaded];
        // Append links to prompt for model consumption
        // Do not append URLs into the prompt; send attachment metadata separately.
        promptText = text;
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Attachment upload failed: $e')));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
    setState(() {
      _isSendingNewChat = true;
      final userMessage = AgentChatMessage(
        id: 'local_user_${const Uuid().v4()}',
        chatId: '',
        sender: MessageSender.user,
        messageType: AgentMessageType.text,
        content: promptText,
        attachedFiles: updatedAttachments,
        sentAt: DateTime.now(),
      );
      final aiPlaceholder = AgentChatMessage(
        id: 'local_ai_${const Uuid().v4()}',
        chatId: '',
        sender: MessageSender.ai,
        messageType: AgentMessageType.toolInProgress,
        content: 'Robin is thinking...',
        sentAt: DateTime.now(),
      );
      _localMessages = [userMessage, aiPlaceholder];
    });

    try {
      final client = Supabase.instance.client;
      final functionsHost = getFunctionsOrigin();
      final functionName = _askMode ? 'agent-chat-handler' : 'agent-handler';
      final url = Uri.parse("$functionsHost/$functionName");
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/x-ndjson',
        'Authorization':
            client.auth.currentSession?.accessToken != null
                ? 'Bearer ${client.auth.currentSession!.accessToken}'
                : '',
        'x-client-info': 'supabase-dart',
      };
      final body = jsonEncode({
        'prompt': promptText,
        'history': [],
        'projectId': widget.projectId,
        'model': _selectedModel,
        'attachedFiles': updatedAttachments,
        'includeThoughts': true,
      });

      final ndjson = NdjsonClient(url: url, headers: headers, body: body);

      final fileEdits = <dynamic>[];
      final filesRead = <Map<String, dynamic>>[];
      final filesSearched = <Map<String, dynamic>>[];
      final inlineEvents = <Map<String, dynamic>>[];
      final toolCalls = <Map<String, dynamic>>[];
      // First-class artifact results captured during stream; entries: { name, artifactId?, result }
      final artifacts = <Map<String, dynamic>>[];
      // Composite tool executions (implement_feature_and_update_todo) captured during stream
      final compositeTasks = <Map<String, dynamic>>[];
      String thoughts = '';
      final List<String> createdArtifactIds = <String>[];
      int aiIndex = 1;
      // Switch placeholder to text mode for live deltas
      setState(() {
        _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
          content: '',
          messageType: AgentMessageType.text,
          toolResults: {'fileEdits': fileEdits},
        );
      });

      String finalText = '';
      // Thoughts expansion flag omitted; UI handles expansion hints via toolResults.ui
      await for (final evt in ndjson.stream()) {
        switch (evt['type']) {
          case 'ping':
            break;
          case 'thought':
            final delta = evt['delta'] as String? ?? '';
            thoughts += delta;
            setState(() {
              final tr = Map<String, dynamic>.from(
                _localMessages[aiIndex].toolResults ?? {'fileEdits': fileEdits},
              );
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = true;
              tr['ui'] = ui;
              final cur = (_localMessages[aiIndex].thoughts ?? '') + delta;
              _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                toolResults: tr,
                thoughts: cur,
              );
            });
            break;
          case 'text':
            final delta = evt['delta'] as String? ?? '';
            finalText += delta;
            setState(() {
              final current = _localMessages[aiIndex].content + delta;
              _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                content: current,
              );
            });
            break;
          case 'file_edit':
            setState(() {
              fileEdits.add(evt);
              _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                toolResults: {
                  'fileEdits': List<dynamic>.from(fileEdits),
                  'events': List<Map<String, dynamic>>.from(inlineEvents),
                },
              );
            });
            break;
          // Skip rendering in-progress markers; rely on tool_result for final inline previews
          case 'tool_result':
            {
              final name = evt['name'] as String?;
              final result = evt['result'];
              final id = evt['id'] as int?;
              if (id != null) {
                final idx = inlineEvents.indexWhere(
                  (e) => (e['id'] as int?) == id,
                );
                if (idx >= 0) {
                  inlineEvents[idx] = {
                    'id': id,
                    'name': name ?? 'tool',
                    'result': result,
                  };
                } else {
                  inlineEvents.add({
                    'id': id,
                    'name': name ?? 'tool',
                    'result': result,
                  });
                }
                setState(() {
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['events'] = List<Map<String, dynamic>>.from(inlineEvents);
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
              }
              if (name == 'read_file' &&
                  result is Map &&
                  (result['status'] == 'success')) {
                setState(() {
                  filesRead.add({
                    'path': result['path'],
                    'lines': result['lines'],
                  });
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['filesRead'] = List<Map<String, dynamic>>.from(filesRead);
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                // Map tool call to filesRead entry
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': 'read_file',
                    'array': 'filesRead',
                    'offset': filesRead.length - 1,
                  });
                }
              } else if (name == 'search' &&
                  result is Map &&
                  (result['status'] == 'success')) {
                setState(() {
                  filesSearched.add({
                    'query': result['query'],
                    'results': result['results'],
                  });
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['filesSearched'] = List<Map<String, dynamic>>.from(
                    filesSearched,
                  );
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': 'search',
                    'array': 'filesSearched',
                    'offset': filesSearched.length - 1,
                  });
                }
              } else if ((name == 'create_file' ||
                      name == 'update_file_content' ||
                      name == 'delete_file') &&
                  result is Map &&
                  (result['status'] == 'success')) {
                // Ensure edit result carries path and contents for inline DiffPreview mapping
                setState(() {
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['fileEdits'] = List<dynamic>.from(fileEdits);
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': name,
                    'array': 'fileEdits',
                    'offset': fileEdits.length - 1,
                  });
                }
              } else if (name == 'implement_feature_and_update_todo' &&
                  result is Map) {
                // Capture composite tool results in a dedicated array for persistence and inline mapping
                setState(() {
                  compositeTasks.add(Map<String, dynamic>.from(result));
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['compositeTasks'] = List<Map<String, dynamic>>.from(
                    compositeTasks,
                  );
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': 'implement_feature_and_update_todo',
                    'array': 'compositeTasks',
                    'offset': compositeTasks.length - 1,
                  });
                }
              } else if (name == 'project_card_preview' ||
                  name == 'todo_list_create' ||
                  name == 'todo_list_check' ||
                  name == 'artifact_read') {
                // Normalize artifact tool results into tool_results.artifacts
                String? artifactId;
                if (result is Map<String, dynamic>) {
                  final rid = result['artifact_id'] ?? result['id'];
                  if (rid != null) artifactId = rid.toString();
                }
                artifacts.add({
                  'name': name,
                  if (artifactId != null) 'artifactId': artifactId,
                  'result': result,
                });
                setState(() {
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  tr['artifacts'] = List<Map<String, dynamic>>.from(artifacts);
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                if (id != null) {
                  final call = <String, dynamic>{
                    'index': id,
                    'name': name,
                    'array': 'artifacts',
                    'offset': artifacts.length - 1,
                  };
                  if (artifactId != null) call['artifactId'] = artifactId;
                  toolCalls.add(call);
                }
              } else if (name == 'analyze_document') {
                // Capture analyze_document results into tool_results.filesAnalyzed
                // Include both success and error payloads; dedupe by file_url if present
                setState(() {
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ??
                        {'fileEdits': fileEdits},
                  );
                  final List<Map<String, dynamic>> filesAnalyzed =
                      List<Map<String, dynamic>>.from(
                        (tr['filesAnalyzed'] as List? ?? const []),
                      );
                  Map<String, dynamic> toAdd;
                  if (result is Map) {
                    toAdd = Map<String, dynamic>.from(result);
                  } else {
                    toAdd = {'status': 'unknown', 'result': result};
                  }
                  // Dedupe by file_url or by mime+byte_length
                  bool isDup = false;
                  final fu = (toAdd['file_url']?.toString() ?? '').trim();
                  if (fu.isNotEmpty) {
                    isDup = filesAnalyzed.any(
                      (e) => (e['file_url']?.toString() ?? '') == fu,
                    );
                  } else {
                    final mt = toAdd['mime_type']?.toString();
                    final bl = toAdd['byte_length']?.toString();
                    if (mt != null && bl != null) {
                      isDup = filesAnalyzed.any(
                        (e) =>
                            (e['mime_type']?.toString() == mt) &&
                            (e['byte_length']?.toString() == bl),
                      );
                    }
                  }
                  if (!isDup) {
                    filesAnalyzed.add(toAdd);
                    tr['filesAnalyzed'] = filesAnalyzed;
                    _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                      toolResults: tr,
                    );
                  }
                });
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': 'analyze_document',
                    'array': 'filesAnalyzed',
                    'offset':
                        (() {
                          final tr = _localMessages[aiIndex].toolResults;
                          final files = tr?['filesAnalyzed'];
                          final len = (files is List) ? files.length : 1;
                          return len - 1;
                        })(),
                  });
                }
              }
              break;
            }
          case 'error':
            setState(() {
              _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                messageType: AgentMessageType.error,
                content: 'Sorry, an error occurred: ${evt['message']}',
              );
            });
            break;
          case 'end':
            if (evt['fileEdits'] is List) {
              setState(() {
                fileEdits
                  ..clear()
                  ..addAll(evt['fileEdits'] as List);
                final tr = Map<String, dynamic>.from(
                  _localMessages[aiIndex].toolResults ?? {},
                );
                tr['fileEdits'] = List<dynamic>.from(fileEdits);
                tr['events'] = List<Map<String, dynamic>>.from(inlineEvents);
                final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
                ui['expandThoughts'] = false;
                tr['ui'] = ui;
                _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                  toolResults: tr,
                );
              });
            }
            // Merge any analyze_document results sent at end
            if (evt['filesAnalyzed'] is List) {
              setState(() {
                final tr = Map<String, dynamic>.from(
                  _localMessages[aiIndex].toolResults ?? {},
                );
                final existing = List<Map<String, dynamic>>.from(
                  (tr['filesAnalyzed'] as List? ?? const []),
                );
                final incoming = List<Map<String, dynamic>>.from(
                  List<dynamic>.from(
                    evt['filesAnalyzed'],
                  ).map((e) => Map<String, dynamic>.from(e as Map)),
                );
                // Dedupe using file_url first, then mime+byte_length
                bool isDupEntry(
                  Map<String, dynamic> a,
                  Map<String, dynamic> b,
                ) {
                  final au = (a['file_url']?.toString() ?? '').trim();
                  final bu = (b['file_url']?.toString() ?? '').trim();
                  if (au.isNotEmpty && bu.isNotEmpty) return au == bu;
                  final am = a['mime_type']?.toString();
                  final bm = b['mime_type']?.toString();
                  final al = a['byte_length']?.toString();
                  final bl = b['byte_length']?.toString();
                  if (am != null && bm != null && al != null && bl != null) {
                    return am == bm && al == bl;
                  }
                  return false;
                }

                final newOffsets = <int>[];
                for (final inc in incoming) {
                  final dup = existing.any((ex) => isDupEntry(ex, inc));
                  if (!dup) {
                    existing.add(inc);
                    newOffsets.add(existing.length - 1);
                  }
                }
                tr['filesAnalyzed'] = existing;
                _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                  toolResults: tr,
                );
                // Add synthetic toolCalls per new offset if missing
                for (final off in newOffsets) {
                  final exists = toolCalls.any(
                    (c) =>
                        c['name'] == 'analyze_document' &&
                        c['array'] == 'filesAnalyzed' &&
                        c['offset'] == off,
                  );
                  if (!exists) {
                    toolCalls.add({
                      'index': (toolCalls.length + 1),
                      'name': 'analyze_document',
                      'array': 'filesAnalyzed',
                      'offset': off,
                    });
                  }
                }
              });
            }
            if (evt['artifactIds'] is List) {
              createdArtifactIds
                ..clear()
                ..addAll(
                  List<dynamic>.from(
                    evt['artifactIds'],
                  ).map((e) => e.toString()),
                );
              // Merge artifactIds into artifacts array and toolCalls if missing
              if (artifacts.isNotEmpty) {
                // Backfill IDs on artifacts
                for (
                  int i = 0;
                  i < artifacts.length && i < createdArtifactIds.length;
                  i++
                ) {
                  final a = Map<String, dynamic>.from(artifacts[i]);
                  a['artifactId'] ??= createdArtifactIds[i];
                  artifacts[i] = a;
                }
                setState(() {
                  final tr = Map<String, dynamic>.from(
                    _localMessages[aiIndex].toolResults ?? {},
                  );
                  tr['artifacts'] = List<Map<String, dynamic>>.from(artifacts);
                  _localMessages[aiIndex] = _localMessages[aiIndex].copyWith(
                    toolResults: tr,
                  );
                });
                // Backfill IDs in toolCalls
                for (int i = 0; i < toolCalls.length; i++) {
                  final c = toolCalls[i];
                  if (c['array'] == 'artifacts' && c['artifactId'] == null) {
                    final off = (c['offset'] is int) ? c['offset'] as int : -1;
                    if (off >= 0 && off < artifacts.length) {
                      final aid = artifacts[off]['artifactId'];
                      if (aid != null) toolCalls[i] = {...c, 'artifactId': aid};
                    }
                  }
                }
              }
            }
            // Collapse thoughts after stream ends; UI accordion defaults collapsed unless user expands later
            break;
        }
      }

      // Generate title from final streamed text and create chat
      final chatService = ref.read(chatServiceProvider);
      final title = await chatService.generateChatTitle(promptText, finalText);

      final chatResponse =
          await client
              .from('agent_chats')
              .insert({
                'project_id': widget.projectId,
                'user_id': client.auth.currentUser!.id,
                'title': title,
              })
              .select('id')
              .single();
      final newChatId = chatResponse['id'] as String;

      // Persist both messages with explicit sent_at ordering
      final sentAtUser = DateTime.now();
      final sentAtAi = sentAtUser.add(const Duration(milliseconds: 10));

      // Sanitize tool_results (strip 'ui') before insert; include filesAnalyzed from streamed tool_results
      final sanitizedToolResults = () {
        final current =
            _localMessages.length > 1
                ? (_localMessages[1].toolResults is Map
                    ? Map<String, dynamic>.from(
                      _localMessages[1].toolResults as Map,
                    )
                    : <String, dynamic>{})
                : <String, dynamic>{};
        if (!current.containsKey('fileEdits')) {
          current['fileEdits'] = fileEdits;
        }
        // Remove UI-only hints
        current.remove('ui');
        return current;
      }();
      // Insert user message then AI message (select id) to link artifacts
      await client.from('agent_chat_messages').insert({
        'chat_id': newChatId,
        'sender': 'user',
        'message_type': 'text',
        'content': promptText,
        'attached_files': updatedAttachments,
        'sent_at': sentAtUser.toIso8601String(),
      });
      final insertedAi =
          await client
              .from('agent_chat_messages')
              .insert({
                'chat_id': newChatId,
                'sender': 'ai',
                'message_type': 'text',
                'content': _localMessages[1].content,
                'thoughts': thoughts.isNotEmpty ? thoughts : null,
                'tool_results': sanitizedToolResults,
                'tool_calls': {'events': toolCalls},
                'sent_at': sentAtAi.toIso8601String(),
              })
              .select('id')
              .single();
      final String? aiMessageId =
          (insertedAi as Map<String, dynamic>?)?['id'] as String?;
      if (aiMessageId != null && createdArtifactIds.isNotEmpty) {
        for (final aid in createdArtifactIds) {
          try {
            await client
                .from('agent_artifacts')
                .update({'chat_id': newChatId, 'message_id': aiMessageId})
                .eq('id', aid);
          } catch (_) {}
        }
      }

      // Refresh explorer and chats list
      ref.read(projectFilesProvider(widget.projectId).notifier).fetchFiles();
      ref.invalidate(projectChatsProvider(widget.projectId));

      setState(() {
        _activeChatId = newChatId;
        _localMessages = [];
        _isSendingNewChat = false;
      });
    } catch (e) {
      setState(() {
        if (_localMessages.length > 1) {
          _localMessages[1] = _localMessages[1].copyWith(
            content: "Sorry, an error occurred: $e",
            messageType: AgentMessageType.error,
          );
        }
        _isSendingNewChat = false;
      });
    }
  }

  void _handleTextChangedForMentions() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    final cursor = selection.baseOffset;
    final beforeCursor = cursor > 0 ? text.substring(0, cursor) : '';
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }
    // Ensure there is no whitespace between @ and cursor
    final mentionCandidate = beforeCursor.substring(atIndex);
    final valid = RegExp(r'^@[^\s@]*$');
    if (valid.hasMatch(mentionCandidate)) {
      final query = mentionCandidate.substring(1);
      setState(() {
        _mentionQuery = query;
        _showMentions = true;
      });
    } else {
      if (_showMentions) setState(() => _showMentions = false);
    }
  }

  void _addAttachments(List<Map<String, dynamic>> files) {
    final byPath = {for (final f in _attachedFiles) f['path']: f};
    for (final f in files) {
      byPath[f['path']] = f;
    }
    setState(() => _attachedFiles = byPath.values.toList());
  }

  void _removeAttachmentByPath(String path) {
    setState(() => _attachedFiles.removeWhere((f) => f['path'] == path));
  }

  Future<void> _pickAndQueueUploads() async {
    try {
      final existingUploadCount =
          _attachedFiles
              .where((f) => f['bytes'] is Uint8List || f['bucket_url'] != null)
              .length;
      final remaining = 3 - existingUploadCount;
      if (remaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can attach up to 3 files.')),
        );
        return;
      }
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
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
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final files = result.files.take(remaining).toList();
      if (result.files.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can attach up to 3 files. Extra files were ignored.',
            ),
          ),
        );
      }
      final uploads = <Map<String, dynamic>>[];
      for (final f in files) {
        final name = f.name;
        final bytes = f.bytes;
        if (bytes == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not read $name.')));
          continue;
        }
        final ext = name.split('.').last.toLowerCase();
        if (!_isAllowedExt(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('upload type not supported')),
          );
          continue;
        }
        final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);
        uploads.add({
          'type': isImage ? 'img' : 'doc',
          'name': name,
          'bytes': bytes,
          'mime_type': _mimeFromExt(ext),
          'size': f.size,
        });
      }
      if (uploads.isEmpty) return;
      setState(() {
        _attachedFiles = [..._attachedFiles, ...uploads];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
    }
  }

  bool _isAllowedExt(String ext) {
    const allowed = [
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
    ];
    return allowed.contains(ext.toLowerCase());
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
      case 'markdown':
        return 'text/markdown';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'xml':
        return 'application/xml';
      default:
        return 'application/octet-stream';
    }
  }

  String _guessMimeFromName(String name) => _mimeFromExt(name.split('.').last);

  void _insertMentionAndAttach(Map<String, dynamic> file) {
    // Replace current @query with @file.path
    final text = _controller.text;
    final selection = _controller.selection;
    final cursor = selection.baseOffset;
    final beforeCursor = cursor > 0 ? text.substring(0, cursor) : '';
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex != -1) {
      final mentionText = '@' + (file['path'] as String);
      final newText =
          text.substring(0, atIndex) + mentionText + text.substring(cursor);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: atIndex + mentionText.length,
        ),
      );
    }
    _addAttachments([file]);
    setState(() {
      _showMentions = false;
      _mentionQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool providerIsSending =
        _activeChatId != null &&
        ref.watch(agentChatProvider(_activeChatId!)).isSending;
    final bool isSending = _isSendingNewChat || providerIsSending;

    // Auto-scroll while streaming, and once after it ends to settle
    if (isSending || _wasStreaming) {
      _scheduleAutoScrollToBottom(reverse: true);
    }
    _wasStreaming = isSending;
    final chatHistory = ref.watch(projectChatsProvider(widget.projectId));
    final projectFilesState = ref.watch(projectFilesProvider(widget.projectId));

    final files = projectFilesState.files;
    final mentionResults =
        _showMentions
            ? files
                .where(
                  (f) =>
                      _mentionQuery.isEmpty ||
                      f.path.toLowerCase().contains(
                        _mentionQuery.toLowerCase(),
                      ),
                )
                .take(8)
                .map(
                  (f) => {
                    'path': f.path,
                    'content': f.content,
                    'file_id': f.id,
                  },
                )
                .toList()
            : const <Map<String, dynamic>>[];

    return Column(
      children: [
        _buildChatHeader(chatHistory),
        Expanded(
          child:
              _activeChatId == null
                  ? _buildInitialOrLocalView()
                  : Consumer(
                    builder: (context, ref, child) {
                      final chatState = ref.watch(
                        agentChatProvider(_activeChatId!),
                      );
                      if (chatState.isLoading && chatState.messages.isEmpty) {
                        return const Center(child: WaveLoader(size: 28));
                      }
                      return ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(16.0),
                        reverse: true,
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final messages = chatState.messages.reversed.toList();
                          final message = messages[index];
                          final isLast = index == 0;
                          final streamingThis =
                              providerIsSending &&
                              isLast &&
                              message.sender == MessageSender.ai;
                          return Padding(
                            key: ValueKey(message.id),
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: AgentMessageBubble(
                              message: message,
                              isLastMessage: isLast,
                              isStreaming: streamingThis,
                              projectId: widget.projectId,
                            ),
                          );
                        },
                      );
                    },
                  ),
        ),
        _buildChatInput(isSending, mentionResults),
      ],
    );
  }

  Widget _buildChatHeader(AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, right: 8.0, left: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: chatHistory.when(
              data: (history) {
                String title = 'New Chat';
                if (_activeChatId != null) {
                  final item = history.firstWhere(
                    (h) => h['id'] == _activeChatId,
                    orElse: () => {},
                  );
                  if (item.isNotEmpty) {
                    title = item['title'] ?? 'Untitled Chat';
                  }
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 4),
          // Artifacts pill
          _ArtifactsPillButton(
            projectId: widget.projectId,
            chatId: _activeChatId,
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white70,
            ),
            tooltip: 'New Chat',
            onPressed:
                () => setState(() {
                  _activeChatId = null;
                  _localMessages = [];
                }),
          ),
          const SizedBox(width: 4),
          chatHistory.when(
            data:
                (history) => PopupMenuButton<String>(
                  tooltip: 'Chat History',
                  icon: const Icon(
                    Icons.manage_history_rounded,
                    color: Colors.white70,
                  ),
                  onSelected:
                      (value) => setState(() {
                        _activeChatId = value;
                        _localMessages = [];
                      }),
                  color: const Color(0xFF1E1E1E),
                  itemBuilder:
                      (BuildContext context) =>
                          history
                              .map(
                                (chat) => PopupMenuItem<String>(
                                  value: chat['id'],
                                  child: Text(
                                    chat['title'] ?? 'Untitled Chat',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                ),
            loading:
                () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: MiniWave(size: 24),
                ),
            error:
                (err, stack) =>
                    const Icon(Icons.error, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialOrLocalView() {
    if (_localMessages.isEmpty) {
      return _buildInitialView();
    }
    return ListView.builder(
      controller: _chatScrollController,
      padding: const EdgeInsets.all(16.0),
      reverse: true,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 1000.0,
      itemCount: _localMessages.length,
      itemBuilder: (context, index) {
        final messages = _localMessages.reversed.toList();
        final message = messages[index];
        return Padding(
          key: ValueKey(message.id),
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: RepaintBoundary(
            child: AgentMessageBubble(
              message: message,
              isLastMessage: index == 0,
              isStreaming:
                  _isSendingNewChat &&
                  index == 0 &&
                  message.sender == MessageSender.ai,
              projectId: widget.projectId,
            ),
          ),
        );
      },
    );
  }

  void _scheduleAutoScrollToBottom({bool reverse = false}) {
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted) return;
      if (!_chatScrollController.hasClients) return;
      final pos = _chatScrollController.position;
      final target = reverse ? pos.minScrollExtent : pos.maxScrollExtent;
      _chatScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
    });
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            color: AppColors.accent.withOpacity(0.8),
            size: 48,
          ),
          const SizedBox(height: 24),
          Text(
            'Start building with Robin',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Describe what you want to build, ask a question, or give an instruction.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 32),
          _SuggestionChip(
            text: 'Create a basic project structure',
            onTap: () {
              _controller.text =
                  'Create a basic project structure for this app.';
              _sendMessage();
            },
          ),
          _SuggestionChip(
            text: 'Add a login page with email and password fields',
            onTap: () {
              _controller.text =
                  'Add a login page with email and password fields';
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(
    bool isSending,
    List<Map<String, dynamic>> mentionResults,
  ) {
    // final filesProvider = ref.read(projectFilesProvider(widget.projectId).notifier);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Mode toggle pills
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ModePill(
                            label: 'Agent',
                            selected: !_askMode,
                            onTap: () => setState(() => _askMode = false),
                          ),
                          _ModePill(
                            label: 'Ask',
                            selected: _askMode,
                            onTap: () => setState(() => _askMode = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_attachedFiles.isNotEmpty)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(
                      left: 4,
                      right: 4,
                      bottom: 6,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              _attachedFiles.map((f) {
                                final hasPath =
                                    f['path'] is String; // code attachment
                                final isUpload =
                                    f['bytes'] is Uint8List ||
                                    f['bucket_url'] != null;
                                final isImg = (f['type'] == 'img');
                                final title =
                                    hasPath
                                        ? (f['path'] as String)
                                        : (f['name'] as String? ?? 'file');
                                final icon =
                                    hasPath
                                        ? Icons.description_outlined
                                        : (isImg
                                            ? Icons.image_outlined
                                            : Icons.insert_drive_file_outlined);
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
                                        icon,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 200,
                                        ),
                                        child: Text(
                                          title,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          if (hasPath) {
                                            _removeAttachmentByPath(
                                              f['path'] as String,
                                            );
                                          } else {
                                            setState(
                                              () => _attachedFiles.remove(f),
                                            );
                                          }
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white60,
                                          size: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (isUpload &&
                                    isImg &&
                                    f['bytes'] is Uint8List) {
                                  return Builder(
                                    builder:
                                        (pillCtx) => MouseRegion(
                                          onEnter:
                                              (_) =>
                                                  _showImageHoverOverlayForPill(
                                                    pillCtx,
                                                    f['bytes'] as Uint8List,
                                                  ),
                                          onExit:
                                              (_) => _removeImageHoverOverlay(),
                                          child: pill,
                                        ),
                                  );
                                }
                                return pill;
                              }).toList(),
                        ),
                        // Hover preview rendered in global overlay
                      ],
                    ),
                  ),
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 6,
                      right: 6,
                      bottom: 4,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: MiniWave(size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uploading attachments…',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_showMentions && mentionResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: mentionResults.length,
                      itemBuilder: (context, index) {
                        final item = mentionResults[index];
                        return InkWell(
                          onTap: () => _insertMentionAndAttach(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_outlined,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item['path'] as String,
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
                        );
                      },
                    ),
                  ),
                Shortcuts(
                  shortcuts: <LogicalKeySet, Intent>{
                    LogicalKeySet(LogicalKeyboardKey.enter):
                        const ActivateIntent(),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<Intent>(
                        onInvoke: (intent) {
                          if (_showMentions && mentionResults.isNotEmpty) {
                            _insertMentionAndAttach(mentionResults.first);
                          }
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 8,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message Robin…',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 12.0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Add',
                          onSelected: (value) async {
                            if (value == 'attach_code') {
                              final selected =
                                  await showDialog<List<Map<String, dynamic>>>(
                                    context: context,
                                    builder:
                                        (context) => AttachCodeDialog(
                                          projectId: widget.projectId,
                                          initiallySelectedPaths:
                                              _attachedFiles
                                                  .map(
                                                    (e) => e['path'] as String,
                                                  )
                                                  .toList(),
                                        ),
                                  );
                              if (selected != null && selected.isNotEmpty) {
                                _addAttachments(selected);
                              }
                            } else if (value == 'upload_file') {
                              await _pickAndQueueUploads();
                            }
                          },
                          color: const Color(0xFF1E1E1E),
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 'attach_code',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.code,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Attach code',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'upload_file',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.upload_file,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Upload file',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildModelToggle(),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon:
                              isSending
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: MiniWave(size: 20),
                                  )
                                  : const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                  ),
                          onPressed: isSending ? null : _sendMessage,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelToggle() {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedModel = value),
      color: const Color(0xFF1E1E1E),
      itemBuilder:
          (context) => [
            PopupMenuItem(
              value: 'gemini-2.5-flash',
              child: Text(
                'Gemini 2.5 Flash',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
            PopupMenuItem(
              value: 'gemini-2.5-flash-lite',
              child: Text(
                'Gemini 2.5 Flash Lite',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              _selectedModel == 'gemini-2.5-flash'
                  ? 'Gemini 2.5 Flash'
                  : 'Gemini 2.5 Flash Lite',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8)),
        ),
      ),
    );
  }
}

class AgentMessageBubble extends ConsumerWidget {
  final AgentChatMessage message;
  final bool isLastMessage;
  final String projectId;
  final bool isStreaming;

  const AgentMessageBubble({
    super.key,
    required this.message,
    required this.projectId,
    this.isLastMessage = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.sender == MessageSender.user;
    final isTool = message.messageType != AgentMessageType.text;

    if (isTool) {
      return _buildToolMessage(message);
    }

    final Map<String, dynamic> toolResultsMap =
        (message.toolResults is Map)
            ? Map<String, dynamic>.from(message.toolResults as Map)
            : <String, dynamic>{};
    final String thoughts = message.thoughts ?? '';
    final bool expandThoughts =
        ((toolResultsMap['ui'] as Map?)?['expandThoughts'] as bool?) ?? false;
    final List<dynamic> edits =
        (message.toolResults != null &&
                message.toolResults is Map &&
                (message.toolResults as Map)["fileEdits"] is List)
            ? List<dynamic>.from(
              (message.toolResults as Map)["fileEdits"] as List,
            )
            : [];
    final List<dynamic> filesRead =
        (toolResultsMap['filesRead'] is List)
            ? List<dynamic>.from(toolResultsMap['filesRead'] as List)
            : const [];
    final List<dynamic> filesSearched =
        (toolResultsMap['filesSearched'] is List)
            ? List<dynamic>.from(toolResultsMap['filesSearched'] as List)
            : const [];

    final List<dynamic> attached =
        message.attachedFiles is List
            ? List<dynamic>.from(message.attachedFiles as List)
            : [];

    // Compute if inline markers exist and reconstruct inline events if needed
    final String contentText = message.content;
    final bool hasInlineMarkers = contentText.contains('[tool:');
    final Map<String, dynamic> toolResultsMap2 =
        (message.toolResults is Map)
            ? Map<String, dynamic>.from(message.toolResults as Map)
            : <String, dynamic>{};
    final List<Map<String, dynamic>> inlineEvents = () {
      final List<Map<String, dynamic>> existing =
          (toolResultsMap2['events'] is List)
              ? List<Map<String, dynamic>>.from(
                toolResultsMap2['events'] as List,
              )
              : const <Map<String, dynamic>>[];
      if (existing.isNotEmpty) return existing;
      // Attempt to reconstruct from toolCalls + toolResults
      final List<dynamic> toolCalls = () {
        final tc = message.toolCalls;
        if (tc is Map<String, dynamic>) {
          final dynamic ev = tc['events'];
          if (ev is List) return List<dynamic>.from(ev);
        }
        if (tc is List) return List<dynamic>.from(tc);
        return const <dynamic>[];
      }();
      if (toolCalls.isEmpty) return const <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> out = [];
      for (final c in toolCalls) {
        if (c is! Map) continue;
        final int? id = (c['index'] is int) ? (c['index'] as int) : null;
        final String name = c['name'] as String? ?? 'tool';
        final String array = c['array'] as String? ?? '';
        final int offset = (c['offset'] is int) ? (c['offset'] as int) : -1;
        dynamic result;
        if (array == 'fileEdits' &&
            offset >= 0 &&
            (toolResultsMap2['fileEdits'] is List)) {
          final list = List<dynamic>.from(toolResultsMap2['fileEdits'] as List);
          if (offset < list.length) {
            final e = list[offset];
            if (e is Map) {
              result = {
                'status': 'success',
                'path': e['path'],
                'old_content': e['old_content'],
                'new_content': e['new_content'],
              };
            }
          }
        } else if (array == 'filesRead' &&
            offset >= 0 &&
            (toolResultsMap2['filesRead'] is List)) {
          final list = List<dynamic>.from(toolResultsMap2['filesRead'] as List);
          if (offset < list.length) {
            final r = list[offset] as Map<String, dynamic>;
            result = {
              'status': 'success',
              'path': r['path'],
              'lines': r['lines'],
            };
          }
        } else if (array == 'filesSearched' &&
            offset >= 0 &&
            (toolResultsMap2['filesSearched'] is List)) {
          final list = List<dynamic>.from(
            toolResultsMap2['filesSearched'] as List,
          );
          if (offset < list.length) {
            final r = list[offset] as Map<String, dynamic>;
            result = {
              'status': 'success',
              'query': r['query'],
              'results': r['results'],
            };
          }
        } else if (array == 'artifacts' &&
            offset >= 0 &&
            (toolResultsMap2['artifacts'] is List)) {
          final list = List<dynamic>.from(toolResultsMap2['artifacts'] as List);
          if (offset < list.length) {
            final r = list[offset];
            if (r is Map<String, dynamic>) {
              // We store artifact entries as { name, artifactId?, result }
              result = r['result'];
            } else {
              result = r;
            }
          }
        } else if (array == 'compositeTasks' &&
            offset >= 0 &&
            (toolResultsMap2['compositeTasks'] is List)) {
          final list = List<dynamic>.from(
            toolResultsMap2['compositeTasks'] as List,
          );
          if (offset < list.length) {
            final r = list[offset];
            if (r is Map<String, dynamic>) {
              // r is the composite tool result map including edits/task_title/etc.
              result = r;
            } else {
              result = r;
            }
          }
        } else if (array == 'filesAnalyzed' &&
            offset >= 0 &&
            (toolResultsMap2['filesAnalyzed'] is List)) {
          final list = List<dynamic>.from(
            toolResultsMap2['filesAnalyzed'] as List,
          );
          if (offset < list.length) {
            final r = list[offset];
            if (r is Map<String, dynamic>) {
              result = r;
            } else {
              result = r;
            }
          }
        }
        out.add({'id': id ?? out.length + 1, 'name': name, 'result': result});
      }
      return out;
    }();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: isUser ? AppColors.darkerAccent : Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft:
                    isUser
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                bottomRight:
                    isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(18),
              ),
              border:
                  isUser
                      ? null
                      : Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && thoughts.isNotEmpty) ...[
                  _ThoughtsAccordion(
                    thoughts: thoughts,
                    expandInitially: expandThoughts,
                  ),
                  const SizedBox(height: 12),
                ],
                if (edits.isNotEmpty &&
                    !isUser &&
                    !(hasInlineMarkers || inlineEvents.isNotEmpty)) ...[
                  EditsSummary(fileEdits: edits),
                  const SizedBox(height: 8),
                  ...edits.map((e) {
                    final path = (e['path'] as String?) ?? 'unknown';
                    final isNew =
                        ((e['operation'] as String?) ?? '').toLowerCase() ==
                            'create' ||
                        ((e['old_content'] as String?) ?? '').isEmpty;
                    return InkWell(
                      onTap: () {
                        try {
                          final files =
                              ref.read(projectFilesProvider(projectId)).files;
                          final file = files.firstWhere((f) => f.path == path);
                          ref.read(codeViewProvider.notifier).openFile(file);
                          ref
                              .read(diffOverlayProvider)
                              .showOverlay(
                                path: path,
                                oldContent: (e['old_content'] as String?) ?? '',
                                newContent: (e['new_content'] as String?) ?? '',
                              );
                          // Expand file tree to this path
                          _expandFileTreeToPath(ref, projectId, path);
                        } catch (_) {}
                      },
                      child: DiffPreview(
                        path: path,
                        oldContent: (e['old_content'] as String?) ?? '',
                        newContent: (e['new_content'] as String?) ?? '',
                        isNew: isNew,
                        onTap: null,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                ],
                if (!isUser &&
                    filesRead.isNotEmpty &&
                    !(hasInlineMarkers || inlineEvents.isNotEmpty)) ...[
                  ...filesRead.map((r) {
                    final path = r['path'] as String? ?? 'unknown';
                    final lines = r['lines']?.toString() ?? '-';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Read $path ($lines lines)',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                ],
                if (!isUser &&
                    filesSearched.isNotEmpty &&
                    !(hasInlineMarkers || inlineEvents.isNotEmpty)) ...[
                  ...filesSearched.map((s) {
                    final query = s['query'] as String? ?? '';
                    final List<dynamic> results =
                        (s['results'] is List)
                            ? List<dynamic>.from(s['results'] as List)
                            : [];
                    return _SearchResultsAccordion(
                      query: query,
                      results: results,
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                if (isUser && attached.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        attached.map((a) {
                          // Code attachment (has 'path' and 'content')
                          if (a is Map &&
                              a['path'] is String &&
                              a['content'] is String) {
                            final path = a['path'] as String;
                            final content = a['content'] as String? ?? '';
                            final preview = content
                                .split('\n')
                                .take(5)
                                .join('\n');
                            return InkWell(
                              onTap: () {
                                final files =
                                    ref
                                        .read(projectFilesProvider(projectId))
                                        .files;
                                final file = files.firstWhere(
                                  (f) => f.path == path,
                                  orElse:
                                      () => throw Exception('File not found'),
                                );
                                ref
                                    .read(codeViewProvider.notifier)
                                    .openFile(file);
                                _expandFileTreeToPath(ref, projectId, path);
                              },
                              child: Container(
                                width: 320,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.description_outlined,
                                          size: 14,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            path,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        preview,
                                        style: GoogleFonts.robotoMono(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Uploaded attachment (has 'type' and 'bucket_url')
                          final isImg = (a['type'] == 'img');
                          final name = (a['name'] as String?) ?? 'attachment';
                          final url = (a['bucket_url'] as String?) ?? '';
                          return InkWell(
                            onTap: () async {
                              if (url.isNotEmpty) {
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              }
                            },
                            child: Container(
                              width: isImg ? 340 : 320,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isImg
                                            ? Icons.image_outlined
                                            : Icons.insert_drive_file_outlined,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (isImg && url.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        url,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        url.isNotEmpty
                                            ? url
                                            : 'No link available',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.robotoMono(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                ],
                if (!isUser && isLastMessage && (message.content.isEmpty))
                  const _TypingDots()
                else
                  _AgentSegmentedMarkdown(
                    data: message.content,
                    inlineEvents: inlineEvents,
                    ref: ref,
                    projectId: projectId,
                  ),
              ],
            ),
          ),
          if (!isUser && isLastMessage && !isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.white54,
                      size: 18,
                    ),
                    tooltip: 'Copy Message',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard!'),
                          backgroundColor: AppColors.darkerAccent,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  _FeedbackButton(
                    icon: Icons.thumb_up_alt_outlined,
                    selected: message.feedback == 'like',
                    onTap: () async {
                      // Optimistic UI update
                      message.feedback == 'like';
                      await Supabase.instance.client
                          .from('agent_chat_messages')
                          .update({'feedback': 'like'})
                          .eq('id', message.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback'),
                          backgroundColor: Colors.grey.withOpacity(0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 2),
                  _FeedbackButton(
                    icon: Icons.thumb_down_alt_outlined,
                    selected: message.feedback == 'dislike',
                    onTap: () async {
                      // Optimistic UI update
                      message.feedback == 'dislike';
                      await Supabase.instance.client
                          .from('agent_chat_messages')
                          .update({'feedback': 'dislike'})
                          .eq('id', message.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback'),
                          backgroundColor: Colors.grey.withOpacity(0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolMessage(AgentChatMessage message) {
    String text;
    Widget icon;

    switch (message.messageType) {
      case AgentMessageType.toolInProgress:
        text = message.content;
        icon = const SizedBox(width: 16, height: 16, child: MiniWave(size: 16));
        break;
      case AgentMessageType.toolResult:
        text = 'Tool execution finished.';
        icon = const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 18,
        );
        break;
      case AgentMessageType.error:
        text = 'Error executing tool.';
        icon = const Icon(Icons.error, color: Colors.redAccent, size: 18);
        break;
      default:
        text = message.content;
        icon = const Icon(Icons.build, size: 18, color: Colors.white70);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontStyle: FontStyle.italic,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ArtifactsPillButton extends StatelessWidget {
  final String projectId;
  final String? chatId;
  const _ArtifactsPillButton({required this.projectId, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: const Icon(Icons.storage_rounded, size: 16, color: Colors.white70),
      label: Text(
        'Artifacts',
        style: GoogleFonts.poppins(color: Colors.white70),
      ),
      onPressed: () async {
        await showDialog(
          context: context,
          builder:
              (ctx) => _ArtifactsDialog(projectId: projectId, chatId: chatId),
        );
      },
    );
  }
}

class _ArtifactsDialog extends StatefulWidget {
  final String projectId;
  final String? chatId;
  const _ArtifactsDialog({required this.projectId, required this.chatId});

  @override
  State<_ArtifactsDialog> createState() => _ArtifactsDialogState();
}

class _ArtifactsDialogState extends State<_ArtifactsDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];
  bool _chatOnly = true; // default: this chat only

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supa = Supabase.instance.client;
      // If chat-only and there is no chat id, show nothing
      if (_chatOnly && (widget.chatId == null || widget.chatId!.isEmpty)) {
        setState(() {
          _rows = const [];
          _loading = false;
        });
        return;
      }
      final table = supa.from('agent_artifacts');
      var query = table
          .select('id, artifact_type, data, key, last_modified, chat_id')
          .eq('project_id', widget.projectId);
      if (_chatOnly && widget.chatId != null && widget.chatId!.isNotEmpty) {
        // Safe to use non-null assertion since we checked for null and emptiness above
        query = query.eq('chat_id', widget.chatId!);
      }
      final res = await query.order('last_modified', ascending: false);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Artifacts',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SmallToggle(
                        label: 'This chat',
                        selected: _chatOnly,
                        onTap: () {
                          if (!_chatOnly) {
                            setState(() => _chatOnly = true);
                            _fetch();
                          }
                        },
                      ),
                      _SmallToggle(
                        label: 'All-time',
                        selected: !_chatOnly,
                        onTap: () {
                          if (_chatOnly) {
                            setState(() => _chatOnly = false);
                            _fetch();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _fetch,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.redAccent),
                ),
              )
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'No artifacts yet for this project.',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _rows.map((row) {
                          final name = _artifactNameFromType(
                            row['artifact_type'] as String?,
                          );
                          final resultPayload = _artifactResultPayload(row);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: AgentToolEventPreviews(
                              events: [
                                {'name': name, 'result': resultPayload},
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
}

class _SmallToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SmallToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

void _expandFileTreeToPath(WidgetRef ref, String projectId, String path) {
  // Force refresh of files to ensure explorer data is present; the tree view will expand on tap.
  // Here we notify the provider so the UI reflects the newly opened file.
  ref.read(projectFilesProvider(projectId).notifier).fetchFiles();
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FeedbackButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? AppColors.accent : Colors.white54,
        ),
      ),
    );
  }
}

class _ThoughtsAccordion extends StatefulWidget {
  final String thoughts;
  final bool expandInitially;
  // onCollapsed parameter removed (unused)
  const _ThoughtsAccordion({
    required this.thoughts,
    this.expandInitially = false,
  });

  @override
  State<_ThoughtsAccordion> createState() => _ThoughtsAccordionState();
}

class _ThoughtsAccordionState extends State<_ThoughtsAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandInitially;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                () => setState(() {
                  _expanded = !_expanded;
                }),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thoughts',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkerAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.darkerAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      'hidden',
                      style: GoogleFonts.poppins(
                        color: AppColors.darkerAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_expanded)
                    Text(
                      'tap to view',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: widget.thoughts,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: GoogleFonts.robotoMono(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      code: GoogleFonts.robotoMono(
                        backgroundColor: Colors.black.withOpacity(0.3),
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsAccordion extends StatefulWidget {
  final String query;
  final List<dynamic> results; // [{ path, matches:[{line,text}] }]
  const _SearchResultsAccordion({required this.query, required this.results});

  @override
  State<_SearchResultsAccordion> createState() =>
      _SearchResultsAccordionState();
}

class _SearchResultsAccordionState extends State<_SearchResultsAccordion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final totalMatches = widget.results.fold<int>(
      0,
      (sum, r) => sum + ((r['matches'] as List?)?.length ?? 0),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
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
                horizontal: 12.0,
                vertical: 10.0,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.search,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Searched for "${widget.query}" in codebase — $totalMatches match(es)',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.results.length,
                  itemBuilder: (context, idx) {
                    final r = widget.results[idx] as Map<String, dynamic>;
                    final path = r['path'] as String? ?? 'unknown';
                    final matches = (r['matches'] as List?) ?? const [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  path,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...matches.map((m) {
                            final line = (m as Map<String, dynamic>)['line'];
                            final text = m['text'];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              child: Text(
                                'L$line  $text',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: WaveLoader(size: 36, color: Colors.white70),
    );
  }
}

// Segmented Markdown for Agent chat: parses fenced code and inline [tool:<id>] markers
class _AgentSegmentedMarkdown extends StatelessWidget {
  final String data;
  final List<Map<String, dynamic>> inlineEvents; // [{ id, name, result? }]
  final WidgetRef ref;
  final String projectId;
  const _AgentSegmentedMarkdown({
    required this.data,
    this.inlineEvents = const [],
    required this.ref,
    required this.projectId,
  });

  // Simple LRU cache for parsed segments by exact content string
  static final Map<String, List<_AgentSegment>> _cache =
      <String, List<_AgentSegment>>{};
  static const int _cacheCap = 64;
  static List<_AgentSegment> _parseSegmentsCached(String input) {
    final existing = _cache.remove(input);
    if (existing != null) {
      _cache[input] = existing; // mark as most recently used
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
            _renderInlineTool(part.toolId)
          else if (part.isCode)
            PlaygroundCodeBlock(code: part.text, language: part.language)
          else
            MarkdownBody(
              data: part.text,
              selectable: true,
              builders: {
                'pre': CodeBlockBuilder(),
                'code': InlineCodeBuilder(),
              },
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
                code: GoogleFonts.robotoMono(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  border: Border(
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 4,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _renderInlineTool(int id) {
    final event = inlineEvents.firstWhere(
      (e) => (e['id'] as int?) == id,
      orElse: () => const {},
    );
    if (event.isEmpty) return const SizedBox.shrink();
    final name = (event['name'] as String?) ?? '';
    final result = event['result'];

    // Map known tools to inline widgets reusing existing components
    switch (name) {
      case 'create_file':
      case 'update_file_content':
      case 'delete_file':
        {
          final path =
              (result is Map)
                  ? (result['path'] as String? ?? 'unknown')
                  : 'unknown';
          final oldContent =
              (result is Map) ? (result['old_content'] as String? ?? '') : '';
          final newContent =
              (result is Map) ? (result['new_content'] as String? ?? '') : '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: DiffPreview(
              path: path,
              oldContent: oldContent,
              newContent: newContent,
              isNew:
                  ((result is Map &&
                          ((result['old_content'] as String?) ?? '').isEmpty) ||
                      (result is Map &&
                          ((result['operation'] as String?) ?? '')
                                  .toLowerCase() ==
                              'create')),
              onTap: () async {
                // First open the file in the code editor
                try {
                  final files = ref.read(projectFilesProvider(projectId)).files;
                  final file = files.firstWhere((f) => f.path == path);
                  ref.read(codeViewProvider.notifier).openFile(file);
                  _expandFileTreeToPath(ref, projectId, path);
                } catch (e) {
                  // File not found, just show overlay anyway
                }

                // Then show the diff overlay
                ref
                    .read(diffOverlayProvider)
                    .showOverlay(
                      path: path,
                      oldContent: oldContent,
                      newContent: newContent,
                    );
              },
            ),
          );
        }
      case 'read_file':
        {
          final path =
              (result is Map)
                  ? (result['path'] as String? ?? 'unknown')
                  : 'unknown';
          final lines =
              (result is Map) ? (result['lines']?.toString() ?? '-') : '-';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Read $path ($lines lines)',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      case 'search':
        {
          final query =
              (result is Map) ? (result['query'] as String? ?? '') : '';
          final results =
              (result is Map && result['results'] is List)
                  ? List<dynamic>.from(result['results'] as List)
                  : const <dynamic>[];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: _SearchResultsAccordion(query: query, results: results),
          );
        }
      case 'project_card_preview':
      case 'todo_list_create':
      case 'todo_list_check':
      case 'artifact_read':
        return AgentToolEventPreviews(
          events: [
            {'name': name, 'result': result},
          ],
        );
      case 'analyze_document':
        // Render using the same preview widget infra
        return AgentToolEventPreviews(
          events: [
            {'name': name, 'result': result},
          ],
        );
      case 'implement_feature_and_update_todo':
        {
          final map =
              (result is Map)
                  ? Map<String, dynamic>.from(result)
                  : <String, dynamic>{};
          final edits =
              (map['edits'] is List)
                  ? List<Map<String, dynamic>>.from(map['edits'] as List)
                  : const <Map<String, dynamic>>[];
          final taskTitle = (map['task_title'] as String?) ?? 'Task';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.task_alt,
                      color: Color(0xFF2CB67D),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Completed: $taskTitle',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final e in edits)
                  Builder(
                    builder: (context) {
                      final path = (e['path'] as String?) ?? 'unknown';
                      final oldC = (e['old_content'] as String?) ?? '';
                      final newC = (e['new_content'] as String?) ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: DiffPreview(
                          path: path,
                          oldContent: oldC,
                          newContent: newC,
                          isNew:
                              ((e['operation'] as String?) ?? '')
                                      .toLowerCase() ==
                                  'create' ||
                              (oldC.isEmpty),
                          onTap: () async {
                            // Try to open file in editor first
                            try {
                              final files =
                                  ref
                                      .read(projectFilesProvider(projectId))
                                      .files;
                              final file = files.firstWhere(
                                (f) => f.path == path,
                              );
                              ref
                                  .read(codeViewProvider.notifier)
                                  .openFile(file);
                              _expandFileTreeToPath(ref, projectId, path);
                            } catch (_) {}
                            // Then show diff overlay
                            ref
                                .read(diffOverlayProvider)
                                .showOverlay(
                                  path: path,
                                  oldContent: oldC,
                                  newContent: newC,
                                );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }
      default:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isNotEmpty ? name : 'tool',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                const JsonEncoder.withIndent('  ').convert(result),
                style: GoogleFonts.robotoMono(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
    }
  }

  static List<_AgentSegment> _parseSegments(String input) {
    final lines = input.split('\n');
    final segments = <_AgentSegment>[];
    final buffer = StringBuffer();
    bool inFence = false;
    String fenceLang = '';

    for (final line in lines) {
      if (!inFence && line.trimLeft().startsWith('[tool:')) {
        if (buffer.isNotEmpty) {
          segments.add(_AgentSegment(text: buffer.toString(), isCode: false));
          buffer.clear();
        }
        final marker = line.trim();
        final idStr = marker.replaceAll(RegExp(r'[^0-9]'), '');
        final id = int.tryParse(idStr) ?? -1;
        segments.add(_AgentSegment.tool(id));
        continue;
      }
      if (!inFence && line.trimLeft().startsWith('```')) {
        if (buffer.isNotEmpty) {
          segments.add(_AgentSegment(text: buffer.toString(), isCode: false));
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
        segments.add(
          _AgentSegment(
            text: buffer.toString(),
            isCode: true,
            language: fenceLang,
          ),
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
        _AgentSegment(
          text: buffer.toString(),
          isCode: inFence,
          language: fenceLang,
        ),
      );
    }
    return segments;
  }
}

class _AgentSegment {
  final String text;
  final bool isCode;
  final String language;
  final bool isToolMarker;
  final int toolId;
  _AgentSegment({
    required this.text,
    required this.isCode,
    this.language = '',
    this.isToolMarker = false,
    this.toolId = -1,
  });
  factory _AgentSegment.tool(int id) =>
      _AgentSegment(text: '', isCode: false, isToolMarker: true, toolId: id);
}
