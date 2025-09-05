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

  PlaygroundMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.sentAt,
    this.attachments = const [],
    this.toolResults,
    this.thoughts,
    this.feedback,
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
  final List<Map<String, dynamic>> canvasFiles = []; // { path, last_modified }
  // Artifacts state
  final List<Map<String, dynamic>> artifacts =
      []; // { id, title, artifact_type, last_modified, data }
  String? selectedCanvasPath;
  String? selectedCanvasContent;
  bool loadingCanvas = false;

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
          ),
        ),
      );
    // Load canvas files for this chat
    try {
      await fetchCanvasFiles();
    } catch (_) {}
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
          await _client.from('canvas_files').select('content').match({
            'chat_id': chatId!,
            'path': path,
          }).single();
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
        .select('path, last_modified')
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
          await _client.from('canvas_files').select('content').match({
            'chat_id': chatId!,
            'path': path,
          }).single();
      selectedCanvasContent = (row['content'] as String?) ?? '';
    } finally {
      loadingCanvas = false;
      notifyListeners();
    }
  }

  void closeCanvas() {
    selectedCanvasPath = null;
    selectedCanvasContent = null;
    loadingCanvas = false;
    notifyListeners();
  }
}

final playgroundProvider = ChangeNotifierProvider<PlaygroundState>(
  (ref) => PlaygroundState(),
);
