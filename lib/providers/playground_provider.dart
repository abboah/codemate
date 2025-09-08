import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:codemate/utils/ndjson_stream.dart';
import 'package:codemate/supabase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class PlaygroundMessage {
  final String id;
  final String sender; // user|ai
  final String content;
  final DateTime sentAt;
  final List<Map<String, dynamic>> attachments;
  final Map<String, dynamic>? toolResults;
  final String? thoughts;
  final String? feedback; // 'like' | 'dislike' | null
  final bool isSpecial; // special prompt sent by app (UI styling)

  PlaygroundMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.attachments = const [],
    this.toolResults,
    this.thoughts,
    this.feedback,
    this.isSpecial = false,
  });
}

class PlaygroundState extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  String? chatId;
  String? chatTitle;
  bool sending = false;
  bool streaming = false;
  String? error;
  final List<PlaygroundMessage> messages = [];
  final List<Map<String, dynamic>> chats = []; // { id, title, created_at }
  // Canvas state
  final List<Map<String, dynamic>> canvasFiles =
      []; // { path, last_modified, description?, file_type?, can_implement_in_canvas?, version_number? }
  // Artifacts state
  final List<Map<String, dynamic>> artifacts =
      []; // { id, title, artifact_type, last_modified, data }
  String? selectedCanvasPath;
  String? selectedCanvasContent;
  Map<String, dynamic>?
  selectedCanvasMeta; // { description, file_type, can_implement_in_canvas, version_number }
  bool loadingCanvas = false;
  // Versions state for current selected canvas
  List<Map<String, dynamic>> selectedCanvasVersions = const [];
  bool loadingVersions = false;
  bool loadingVersionPreview = false;
  int?
  previewVersionNumber; // when not null, canvas shows a historical version without changing DB

  // Cache for a selected version preview content (to support quick compare/restore UI)
  Map<int, String> _versionContentCache = {};

  Future<String?> readCanvasVersion({
    required String path,
    required int versionNumber,
  }) async {
    if (chatId == null) return null;
    try {
      loadingVersionPreview = true;
      notifyListeners();
      // Resolve file id
      final fileRow =
          await _client.from('canvas_files').select('id').match({
            'chat_id': chatId!,
            'path': path,
          }).single();
      final snap =
          await _client
              .from('canvas_file_versions')
              .select(
                'content, description, file_type, can_implement_in_canvas',
              )
              .eq('file_id', fileRow['id'])
              .eq('version_number', versionNumber)
              .single();
      final content = (snap['content'] as String?) ?? '';
      _versionContentCache[versionNumber] = content;
      return content;
    } catch (_) {
      return null;
    } finally {
      loadingVersionPreview = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>?> readVersionAndLatest({
    required String path,
    required int versionNumber,
  }) async {
    // Returns { old: versionContent, latest: currentContent }
    final latest =
        selectedCanvasContent ?? await fetchCanvasFileContent(path) ?? '';
    String? old = _versionContentCache[versionNumber];
    old ??= await readCanvasVersion(path: path, versionNumber: versionNumber);
    if (old == null) return null;
    return {'old': old, 'latest': latest};
  }

  // Enter a temporary preview of a historical version without modifying DB state
  Future<void> enterCanvasVersionPreview({
    required String path,
    required int versionNumber,
  }) async {
    if (chatId == null) return;
    loadingCanvas = true;
    notifyListeners();
    try {
      // Resolve file id and fetch snapshot with meta
      final fileRow =
          await _client.from('canvas_files').select('id').match({
            'chat_id': chatId!,
            'path': path,
          }).single();
      final snap =
          await _client
              .from('canvas_file_versions')
              .select(
                'content, description, file_type, can_implement_in_canvas',
              )
              .eq('file_id', fileRow['id'])
              .eq('version_number', versionNumber)
              .single();
      selectedCanvasPath = path; // ensure path is set
      selectedCanvasContent = (snap['content'] as String?) ?? '';
      selectedCanvasMeta = {
        'description': snap['description'],
        'file_type': snap['file_type'],
        'can_implement_in_canvas': snap['can_implement_in_canvas'] ?? false,
        'version_number': versionNumber,
      };
      previewVersionNumber = versionNumber;
    } finally {
      loadingCanvas = false;
      notifyListeners();
    }
  }

  Future<void> exitCanvasVersionPreview() async {
    if (chatId == null) return;
    final path = selectedCanvasPath;
    previewVersionNumber = null;
    notifyListeners();
    if (path != null) {
      await openCanvasFile(path); // reload latest from DB
    }
  }

  Future<void> fetchChats() async {
    final rows = await _client
        .from('playground_chats')
        .select('id, title, created_at')
        .order('created_at', ascending: false);
    chats
      ..clear()
      ..addAll(List<Map<String, dynamic>>.from(rows));
    notifyListeners();
  }

  Future<void> newChat() async {
    chatId = null;
    chatTitle = null;
    messages.clear();
    canvasFiles.clear();
    selectedCanvasPath = null;
    selectedCanvasContent = null;
    notifyListeners();
  }

  Future<void> loadChat(String chatId) async {
    this.chatId = chatId;
    // Reset any temporary version preview state on chat switch
    previewVersionNumber = null;
    selectedCanvasVersions = const [];
    _versionContentCache.clear();
    // Load chat title
    try {
      final row =
          await _client
              .from('playground_chats')
              .select('title')
              .eq('id', chatId)
              .single();
      chatTitle = row['title'] as String?;
    } catch (_) {}
    final rows = await _client
        .from('playground_chat_messages')
        .select()
        .eq('chat_id', chatId)
        .order('sent_at', ascending: true);
    messages
      ..clear()
      ..addAll(
        List<Map<String, dynamic>>.from(rows).map(
          (m) => PlaygroundMessage(
            id: m['id'],
            sender: m['sender'],
            content: m['content'] ?? '',
            sentAt: DateTime.parse(m['sent_at']),
            attachments: List<Map<String, dynamic>>.from(
              m['attached_files'] ?? [],
            ),
            toolResults: m['tool_results'] as Map<String, dynamic>?,
            thoughts: m['thoughts'] as String?,
            feedback: m['feedback'] as String?,
            // Messages loaded from DB are not tagged special in UI by default
            isSpecial: (m['is_special'] == true),
          ),
        ),
      );
    // Load canvas files for this chat and open the most recent file if available
    try {
      await fetchCanvasFiles();
      if (canvasFiles.isNotEmpty) {
        // Pick latest by last_modified (desc)
        canvasFiles.sort((a, b) {
          final as = (a['last_modified'] as String?) ?? '';
          final bs = (b['last_modified'] as String?) ?? '';
          return bs.compareTo(as);
        });
        final latestPath = canvasFiles.first['path'] as String?;
        if (latestPath != null) {
          await openCanvasFile(latestPath);
        }
      } else {
        closeCanvas();
      }
    } catch (_) {
      closeCanvas();
    }
    // Load artifacts for this chat
    try {
      await fetchArtifacts();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> send({
    required String text,
    required List<Map<String, dynamic>> attachments,
    String model = 'gemini-2.5-flash',
  }) async {
    if (sending) return;
    sending = true;
    notifyListeners();

    final aiId = UniqueKey().toString();

    messages.add(
      PlaygroundMessage(
        id: UniqueKey().toString(),
        sender: 'user',
        content: text,
        sentAt: DateTime.now(),
        attachments: attachments,
        isSpecial: false,
      ),
    );
    messages.add(
      PlaygroundMessage(
        id: aiId,
        sender: 'ai',
        content: '',
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      // Ensure a chat exists; if not, create one client-side with AI-generated title
      if (chatId == null) {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) {
          throw Exception('Not authenticated');
        }
        final title = await _generateChatTitle(text);
        final newChat =
            await _client
                .from('playground_chats')
                .insert({'user_id': uid, 'title': title})
                .select('id, title')
                .single();
        chatId = newChat['id'] as String?;
        chatTitle = newChat['title'] as String? ?? title;
        // Refresh history now that a chat exists
        try {
          await fetchChats();
        } catch (_) {}
      }

      final functionsHost = getFunctionsOrigin();
      final url = Uri.parse("$functionsHost/playground-handler");
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/x-ndjson',
        'Authorization':
            _client.auth.currentSession?.accessToken != null
                ? 'Bearer ${_client.auth.currentSession!.accessToken}'
                : '',
        'x-client-info': 'supabase-dart',
      };
      final body = jsonEncode({
        'prompt': text,
        'history': [],
        'chatId': chatId,
        'model': model,
        'attachments': attachments,
        'includeThoughts': true,
      });

      final ndjson = NdjsonClient(url: url, headers: headers, body: body);
      streaming = true;
      notifyListeners();

      String textSoFar = '';
      String thoughtsSoFar = '';
      final toolEvents = <Map<String, dynamic>>[];

      await for (final evt in ndjson.stream()) {
        switch (evt['type']) {
          case 'start':
            if (evt['chatId'] is String) chatId = evt['chatId'];
            if (evt['title'] is String) chatTitle = evt['title'];
            notifyListeners();
            break;
          case 'text':
            textSoFar += (evt['delta'] as String? ?? '');
            final i = messages.indexWhere((m) => m.id == aiId);
            if (i != -1) {
              messages[i] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: textSoFar,
                sentAt: messages[i].sentAt,
                thoughts: messages[i].thoughts,
                toolResults: messages[i].toolResults,
              );
              notifyListeners();
            }
            break;
          case 'thought':
            thoughtsSoFar += (evt['delta'] as String? ?? '');
            final ti = messages.indexWhere((m) => m.id == aiId);
            if (ti != -1) {
              messages[ti] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ti].content,
                thoughts: thoughtsSoFar,
                toolResults: messages[ti].toolResults,
                sentAt: messages[ti].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'tool_in_progress':
            final id = evt['id'];
            final name = evt['name'];
            toolEvents.add({
              'id': id,
              'name': name,
              'result': {'status': 'in_progress'},
            });
            // Update inline tool events on the fly
            final ip = messages.indexWhere((m) => m.id == aiId);
            if (ip != -1) {
              messages[ip] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ip].content,
                thoughts: messages[ip].thoughts,
                toolResults: {
                  'events': List<Map<String, dynamic>>.from(toolEvents),
                },
                sentAt: messages[ip].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'tool_result':
            final id = evt['id'];
            final name = evt['name'];
            final res = evt['result'];
            final idx = toolEvents.indexWhere((e) => e['id'] == id);
            if (idx != -1) {
              toolEvents[idx] = {'id': id, 'name': name, 'result': res};
            } else {
              toolEvents.add({'id': id, 'name': name, 'result': res});
            }
            // Update inline immediately
            final ip2 = messages.indexWhere((m) => m.id == aiId);
            if (ip2 != -1) {
              messages[ip2] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ip2].content,
                thoughts: messages[ip2].thoughts,
                toolResults: {
                  'events': List<Map<String, dynamic>>.from(toolEvents),
                },
                sentAt: messages[ip2].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'error':
            error = evt['message'] as String?;
            break;
          case 'end':
            final i = messages.indexWhere((m) => m.id == aiId);
            if (i != -1) {
              // First, finalize content and tool events
              messages[i] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: textSoFar,
                thoughts: thoughtsSoFar.isNotEmpty ? thoughtsSoFar : null,
                toolResults: {'events': toolEvents},
                sentAt: messages[i].sentAt,
              );
              // Replace temp id with DB id if provided
              final newId =
                  (evt['messageId'] is String &&
                          (evt['messageId'] as String).isNotEmpty)
                      ? evt['messageId'] as String
                      : aiId;
              messages[i] = PlaygroundMessage(
                id: newId,
                sender: messages[i].sender,
                content: messages[i].content,
                sentAt: messages[i].sentAt,
                attachments: messages[i].attachments,
                toolResults: messages[i].toolResults,
                thoughts: messages[i].thoughts,
                feedback: messages[i].feedback,
              );
            }
            // Refresh chat list to include newly created chat with title
            try {
              await fetchChats();
            } catch (_) {}
            // Refresh canvas files as tools may have modified them
            try {
              await fetchCanvasFiles();
            } catch (_) {}
            // Refresh artifacts list
            try {
              await fetchArtifacts();
            } catch (_) {}
            break;
        }
      }
    } finally {
      streaming = false;
      sending = false;
      notifyListeners();
    }
  }

  // Special prompt path: show a tagged user bubble locally (purple style), but send only the actual prompt to backend/model.
  Future<void> sendSpecial({
    required String faceText,
    required String actualPrompt,
    required List<Map<String, dynamic>> attachments,
    String model = 'gemini-2.5-flash',
  }) async {
    if (sending) return;
    sending = true;
    notifyListeners();

    final aiId = UniqueKey().toString();
    // Local user bubble with special styling
    messages.add(
      PlaygroundMessage(
        id: UniqueKey().toString(),
        sender: 'user',
        content: faceText,
        sentAt: DateTime.now(),
        attachments: attachments,
        isSpecial: true,
      ),
    );
    messages.add(
      PlaygroundMessage(
        id: aiId,
        sender: 'ai',
        content: '',
        sentAt: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      // Ensure a chat exists
      if (chatId == null) {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) {
          throw Exception('Not authenticated');
        }
        final title = await _generateChatTitle(actualPrompt);
        final newChat = await _client
            .from('playground_chats')
            .insert({'user_id': uid, 'title': title})
            .select('id, title')
            .single();
        chatId = newChat['id'] as String?;
        chatTitle = newChat['title'] as String? ?? title;
        try { await fetchChats(); } catch (_) {}
      }

      final functionsHost = getFunctionsOrigin();
      final url = Uri.parse("$functionsHost/playground-handler");
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/x-ndjson',
        'Authorization':
            _client.auth.currentSession?.accessToken != null
                ? 'Bearer ${_client.auth.currentSession!.accessToken}'
                : '',
        'x-client-info': 'supabase-dart',
      };
      final body = jsonEncode({
        'prompt': actualPrompt, // important: send only actual prompt
        'history': [],
        'chatId': chatId,
        'model': model,
        'attachments': attachments,
        'includeThoughts': true,
        'isSpecial': true,
        'faceText': faceText,
      });

      final ndjson = NdjsonClient(url: url, headers: headers, body: body);
      streaming = true;
      notifyListeners();

      String textSoFar = '';
      String thoughtsSoFar = '';
      final toolEvents = <Map<String, dynamic>>[];

      await for (final evt in ndjson.stream()) {
        switch (evt['type']) {
          case 'start':
            if (evt['chatId'] is String) chatId = evt['chatId'];
            if (evt['title'] is String) chatTitle = evt['title'];
            notifyListeners();
            break;
          case 'text':
            textSoFar += (evt['delta'] as String? ?? '');
            final i = messages.indexWhere((m) => m.id == aiId);
            if (i != -1) {
              messages[i] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: textSoFar,
                sentAt: messages[i].sentAt,
                thoughts: messages[i].thoughts,
                toolResults: messages[i].toolResults,
              );
              notifyListeners();
            }
            break;
          case 'thought':
            thoughtsSoFar += (evt['delta'] as String? ?? '');
            final ti = messages.indexWhere((m) => m.id == aiId);
            if (ti != -1) {
              messages[ti] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ti].content,
                thoughts: thoughtsSoFar,
                toolResults: messages[ti].toolResults,
                sentAt: messages[ti].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'tool_in_progress':
            final id = evt['id'];
            final name = evt['name'];
            toolEvents.add({ 'id': id, 'name': name, 'result': {'status': 'in_progress'} });
            final ip = messages.indexWhere((m) => m.id == aiId);
            if (ip != -1) {
              messages[ip] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ip].content,
                thoughts: messages[ip].thoughts,
                toolResults: { 'events': List<Map<String, dynamic>>.from(toolEvents) },
                sentAt: messages[ip].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'tool_result':
            final id = evt['id'];
            final name = evt['name'];
            final res = evt['result'];
            final idx = toolEvents.indexWhere((e) => e['id'] == id);
            if (idx != -1) { toolEvents[idx] = { 'id': id, 'name': name, 'result': res }; }
            else { toolEvents.add({ 'id': id, 'name': name, 'result': res }); }
            final ip2 = messages.indexWhere((m) => m.id == aiId);
            if (ip2 != -1) {
              messages[ip2] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: messages[ip2].content,
                thoughts: messages[ip2].thoughts,
                toolResults: { 'events': List<Map<String, dynamic>>.from(toolEvents) },
                sentAt: messages[ip2].sentAt,
              );
              notifyListeners();
            }
            break;
          case 'error':
            error = evt['message'] as String?;
            break;
          case 'end':
            final i = messages.indexWhere((m) => m.id == aiId);
            if (i != -1) {
              messages[i] = PlaygroundMessage(
                id: aiId,
                sender: 'ai',
                content: textSoFar,
                thoughts: thoughtsSoFar.isNotEmpty ? thoughtsSoFar : null,
                toolResults: { 'events': toolEvents },
                sentAt: messages[i].sentAt,
              );
            }
            try { await fetchChats(); } catch (_) {}
            try { await fetchCanvasFiles(); } catch (_) {}
            try { await fetchArtifacts(); } catch (_) {}
            break;
        }
      }
    } finally {
      streaming = false;
      sending = false;
      notifyListeners();
    }
  }

  Future<String> _generateChatTitle(String firstMessage) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty)
        return firstMessage.trim().isEmpty
            ? 'New Chat'
            : firstMessage.trim().split('\n').first.substring(0, 60);
      final model = GenerativeModel(
        model: 'gemini-2.5-flash-lite',
        apiKey: apiKey,
      );
      final titlePrompt = """
        Based on the following conversation, create a very short, concise title (5 words or less).

        USER: "$firstMessage"

        TITLE:
      """;
      final resp = await model.generateContent([Content.text(titlePrompt)]);
      var t = resp.text?.trim() ?? '';
      if (t.isEmpty) t = firstMessage.trim();
      // Sanitize to <= 5 words
      final words =
          t
              .replaceAll('\n', ' ')
              .replaceAll('"', '')
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
      if (words.length > 5) t = words.take(5).join(' ');
      if (t.isEmpty) t = 'New Chat';
      return t;
    } catch (_) {
      return firstMessage.trim().isEmpty
          ? 'New Chat'
          : firstMessage.trim().split('\n').first.substring(0, 60);
    }
  }

  Future<void> saveFeedback({required String kind}) async {
    if (chatId == null) return;
    try {
      await _client
          .from('playground_chats')
          .update({'feedback': kind})
          .eq('id', chatId!);
    } catch (_) {}
  }

  Future<String?> fetchCanvasFileContent(String path) async {
    if (chatId == null) return null;
    try {
      final row =
          await _client
              .from('canvas_files')
              .select(
                'content, description, file_type, can_implement_in_canvas, version_number',
              )
              .match({'chat_id': chatId!, 'path': path})
              .single();
      // Update selected meta opportunistically if this matches
      if (selectedCanvasPath == path) {
        selectedCanvasMeta = {
          'description': row['description'],
          'file_type': row['file_type'],
          'can_implement_in_canvas': row['can_implement_in_canvas'],
          'version_number': row['version_number'],
        };
        notifyListeners();
      }
      return (row['content'] as String?) ?? '';
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMessageFeedback({
    required String messageId,
    String? kind,
  }) async {
    // Optimistic update
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final m = messages[idx];
      messages[idx] = PlaygroundMessage(
        id: m.id,
        sender: m.sender,
        content: m.content,
        sentAt: m.sentAt,
        attachments: m.attachments,
        toolResults: m.toolResults,
        thoughts: m.thoughts,
        feedback: kind,
      );
      notifyListeners();
    }
    try {
      await _client
          .from('playground_chat_messages')
          .update({'feedback': kind})
          .eq('id', messageId);
    } catch (_) {}
  }

  // Canvas helpers
  Future<void> fetchCanvasFiles() async {
    if (chatId == null) {
      canvasFiles.clear();
      notifyListeners();
      return;
    }
    final rows = await _client
        .from('canvas_files')
        .select(
          'path, last_modified, description, file_type, can_implement_in_canvas, version_number',
        )
        .eq('chat_id', chatId!)
        .order('path', ascending: true);
    canvasFiles
      ..clear()
      ..addAll(List<Map<String, dynamic>>.from(rows));
    notifyListeners();
  }

  // Artifacts helpers
  Future<void> fetchArtifacts() async {
    if (chatId == null) {
      artifacts.clear();
      notifyListeners();
      return;
    }
    final rows = await _client
        .from('playground_artifacts')
        .select('id, artifact_type, data, last_modified')
        .eq('chat_id', chatId!)
        .order('last_modified', ascending: false);
    final out = <Map<String, dynamic>>[];
    for (final r in List<Map<String, dynamic>>.from(rows)) {
      final data = r['data'] as Map<String, dynamic>?;
      final title =
          (data?['title'] as String?) ??
          (data?['name'] as String?) ??
          (r['artifact_type'] as String? ?? 'untitled');
      out.add({
        'id': r['id'],
        'artifact_type': r['artifact_type'],
        'title': title,
        'last_modified': r['last_modified'],
        'data': data,
      });
    }
    artifacts
      ..clear()
      ..addAll(out);
    notifyListeners();
  }

  Future<void> openCanvasFile(String path) async {
    if (chatId == null) return;
    loadingCanvas = true;
    selectedCanvasPath = path;
    notifyListeners();
    try {
      final row =
          await _client
              .from('canvas_files')
              .select(
                'content, description, file_type, can_implement_in_canvas, version_number',
              )
              .match({'chat_id': chatId!, 'path': path})
              .single();
      selectedCanvasContent = (row['content'] as String?) ?? '';
      selectedCanvasMeta = {
        'description': row['description'],
        'file_type': row['file_type'],
        'can_implement_in_canvas': row['can_implement_in_canvas'],
        'version_number': row['version_number'],
      };
      // Load versions list lazily
      try {
        await fetchCanvasVersions(path);
      } catch (_) {}
    } finally {
      loadingCanvas = false;
      notifyListeners();
    }
  }

  void closeCanvas() {
    selectedCanvasPath = null;
    selectedCanvasContent = null;
    selectedCanvasMeta = null;
    selectedCanvasVersions = const [];
    loadingCanvas = false;
    notifyListeners();
  }

  Future<void> fetchCanvasVersions(String path) async {
    if (chatId == null) return;
    loadingVersions = true;
    notifyListeners();
    try {
      // Call edge function tool via RPC-equivalent table read
      final fileRow =
          await _client.from('canvas_files').select('id').match({
            'chat_id': chatId!,
            'path': path,
          }).single();
      final versions = await _client
          .from('canvas_file_versions')
          .select(
            'version_number, created_at, description, file_type, can_implement_in_canvas',
          )
          .eq('file_id', fileRow['id'])
          .order('version_number', ascending: false)
          .limit(30);
      selectedCanvasVersions = List<Map<String, dynamic>>.from(versions);
    } catch (_) {
      selectedCanvasVersions = const [];
    } finally {
      loadingVersions = false;
      notifyListeners();
    }
  }

  Future<bool> restoreCanvasVersion({
    required String path,
    required int versionNumber,
  }) async {
    if (chatId == null) return false;
    try {
      // Read the snapshot content
      final fileRow =
          await _client.from('canvas_files').select('id, version_number').match(
            {'chat_id': chatId!, 'path': path},
          ).single();
      final snapshot =
          await _client
              .from('canvas_file_versions')
              .select(
                'content, description, file_type, can_implement_in_canvas',
              )
              .eq('file_id', fileRow['id'])
              .eq('version_number', versionNumber)
              .single();
      final nextVersion = (fileRow['version_number'] as int? ?? 1) + 1;
      await _client
          .from('canvas_files')
          .update({
            'content': snapshot['content'] ?? '',
            'description': snapshot['description'],
            'file_type': snapshot['file_type'],
            'can_implement_in_canvas':
                snapshot['can_implement_in_canvas'] ?? false,
            'version_number': nextVersion,
            'last_modified': DateTime.now().toIso8601String(),
          })
          .match({'chat_id': chatId!, 'path': path});
      // Refresh open file and versions
      await openCanvasFile(path);
      await fetchCanvasVersions(path);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final playgroundProvider = ChangeNotifierProvider<PlaygroundState>(
  (ref) => PlaygroundState(),
);
