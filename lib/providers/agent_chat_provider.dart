import 'dart:async';
import 'dart:convert';
import 'package:codemate/models/agent_chat_message.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:codemate/utils/ndjson_stream.dart';
import 'package:codemate/supabase_config.dart';

final chatServiceProvider = Provider((ref) => ChatService());

final projectChatsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projectId) async {
  final response = await Supabase.instance.client
      .from('agent_chats')
      .select('id, title, created_at')
      .eq('project_id', projectId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

final agentChatProvider =
    ChangeNotifierProvider.family<AgentChatNotifier, String>((ref, chatId) {
  return AgentChatNotifier(chatId, ref.read(chatServiceProvider), ref);
});

class AgentChatNotifier extends ChangeNotifier {
  final String chatId;
  final ChatService _chatService;
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final Ref _ref;

  AgentChatNotifier(this.chatId, this._chatService, this._ref) {
    if (chatId.isNotEmpty) {
      fetchMessages();
    }
  }

  List<AgentChatMessage> _messages = [];
  List<AgentChatMessage> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _error;
  String? get error => _error;

  // Internal mutable fields for streaming state
  StreamSubscription<String>? _streamSub;
  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  Future<void> fetchMessages() async {
    if (chatId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _client
          .from('agent_chat_messages')
          .select()
          .eq('chat_id', chatId)
          .order('sent_at', ascending: true);

      _messages = response.map((data) => AgentChatMessage.fromMap(data)).toList();
      _error = null;
    } catch (e) {
      _error = "Failed to fetch messages: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String text,
    required String model,
    required String projectId,
    List<Map<String, dynamic>> attachedFiles = const [],
    bool useAskHandler = false,
    bool stream = true,
  }) async {
    _isSending = true;
    notifyListeners();

    if (chatId.isEmpty) return;

    final userMessage = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.user,
      messageType: AgentMessageType.text,
      content: text,
      attachedFiles: attachedFiles,
      sentAt: DateTime.now(),
    );

    final aiPlaceholder = AgentChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      sender: MessageSender.ai,
      messageType: AgentMessageType.toolInProgress,
      content: 'Robin is thinking...',
      sentAt: DateTime.now(),
    );

    _messages.add(userMessage);
    _messages.add(aiPlaceholder);
    notifyListeners();

    try {
      if (stream) {
        await _sendMessageStream(
          userMessage: userMessage,
          aiPlaceholderId: aiPlaceholder.id,
          text: text,
          model: model,
          projectId: projectId,
          attachedFiles: attachedFiles,
          functionName: useAskHandler ? 'agent-chat-handler' : 'agent-handler',
        );
        return;
      }
       // 1. Prepare history for the backend function
       final historyForBackend = _messages
           .where((m) => m.id != userMessage.id && m.id != aiPlaceholder.id && m.messageType == AgentMessageType.text)
           .map((m) => {
                 "role": m.sender == MessageSender.user ? "user" : "model",
                 "parts": [{"text": m.content}]
               })
           .toList();

       final functionName = useAskHandler ? 'agent-chat-handler' : 'agent-handler';

       // 2. Invoke the Supabase Edge Function
       final response = await _client.functions.invoke(
         functionName,
         body: {
           'prompt': text,
           'history': historyForBackend,
           'projectId': projectId,
           'model': model,
           'attachedFiles': attachedFiles,
            'includeThoughts': true,
         },
       );

       if (response.status != 200) {
         throw Exception('Backend function failed: ${response.data}');
       }

       final Map<String, dynamic> result = response.data as Map<String, dynamic>;
       final aiResponseContent = result['text'] as String? ?? '';
       final List<dynamic> fileEdits = (result['fileEdits'] as List?) ?? [];

       // 3. Prepare the AI message for streaming and show tool results immediately
       final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
       if (index != -1) {
         _messages[index] = aiPlaceholder.copyWith(
           content: '',
           messageType: AgentMessageType.text,
           toolResults: { 'fileEdits': fileEdits },
         );
         notifyListeners();

         // 4. Illusion streaming: gradually append text to placeholder
         const chunkSize = 24;
         for (int i = 0; i < aiResponseContent.length; i += chunkSize) {
           final end = (i + chunkSize < aiResponseContent.length) ? i + chunkSize : aiResponseContent.length;
           final current = _messages[index].content + aiResponseContent.substring(i, end);
           _messages[index] = _messages[index].copyWith(
             content: current,
           );
           notifyListeners();
           await Future.delayed(const Duration(milliseconds: 12));
         }
       }

       // 5. Persist messages to the database once complete
  await _client.from('agent_chat_messages').insert(userMessage.toMap());
  final aiWithToolResults = _messages[index];
  await _client.from('agent_chat_messages').insert(aiWithToolResults.toMap());

       // 6. Refresh the file tree in case the agent modified files
       _ref.read(projectFilesProvider(projectId).notifier).fetchFiles();

    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if(index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: "Sorry, an error occurred: $e",
          messageType: AgentMessageType.error,
        );
      }
      _error = "Failed to send message: $e";
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _sendMessageStream({
    required AgentChatMessage userMessage,
    required String aiPlaceholderId,
    required String text,
    required String model,
    required String projectId,
    required List<Map<String, dynamic>> attachedFiles,
    required String functionName,
  }) async {
    // Prepare history excluding the messages just added
    final historyForBackend = _messages
        .where((m) => m.id != userMessage.id && m.id != aiPlaceholderId && m.messageType == AgentMessageType.text)
        .map((m) => {
              "role": m.sender == MessageSender.user ? "user" : "model",
              "parts": [{"text": m.content}]
            })
        .toList();

    // Construct request to Supabase Edge Function (NDJSON stream)
  // Build Edge Functions URL from configured SUPABASE_URL
  final url = Uri.parse("${getFunctionsOrigin()}/$functionName");
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/x-ndjson',
      'Authorization': _client.auth.currentSession?.accessToken != null
          ? 'Bearer ${_client.auth.currentSession!.accessToken}'
          : '',
      'x-client-info': 'supabase-dart',
    };
    final body = jsonEncode({
      'prompt': text,
      'history': historyForBackend,
      'projectId': projectId,
      'model': model,
      'attachedFiles': attachedFiles,
      'includeThoughts': true,
    });

    _isStreaming = true;
    notifyListeners();

  final ndjson = NdjsonClient(url: url, headers: headers, body: body);

    final index = _messages.indexWhere((m) => m.id == aiPlaceholderId);
    if (index == -1) return;

    // Initialize AI message to text mode and clear content
    _messages[index] = _messages[index].copyWith(
      content: '',
      messageType: AgentMessageType.text,
      toolResults: { 'fileEdits': <dynamic>[] },
    );
    notifyListeners();

  final fileEdits = <dynamic>[];
  final filesRead = <Map<String, dynamic>>[]; // { path, lines }
  final filesSearched = <Map<String, dynamic>>[]; // { query, results: [{path, matches:[{line,text}]}] }
  final StringBuffer thoughtsBuf = StringBuffer();

    // Parse NDJSON lines
    await for (final evt in ndjson.stream()) {
      switch (evt['type']) {
        case 'ping':
          // keep-alive
          break;
        case 'start':
          // no-op
          break;
        case 'thought':
          final delta = evt['delta'] as String? ?? '';
          if (delta.isNotEmpty) thoughtsBuf.write(delta);
          final currentTR = Map<String, dynamic>.from(_messages[index].toolResults ?? {'fileEdits': fileEdits});
          currentTR['ui'] = {...(currentTR['ui'] as Map? ?? {}), 'expandThoughts': true};
          final currentThoughts = (_messages[index].thoughts ?? '') + delta;
          _messages[index] = _messages[index].copyWith(toolResults: currentTR, thoughts: currentThoughts);
          notifyListeners();
          break;
        case 'text':
          final delta = evt['delta'] as String? ?? '';
          final current = _messages[index].content + delta;
          final tr = Map<String, dynamic>.from(_messages[index].toolResults ?? {'fileEdits': fileEdits});
          // If thoughts have been streaming, keep expanded until tools start
          tr['ui'] = {...(tr['ui'] as Map? ?? {}), 'expandThoughts': true};
          _messages[index] = _messages[index].copyWith(content: current, toolResults: tr);
          notifyListeners();
          break;
        case 'file_edit':
          fileEdits.add(evt);
          final tr = Map<String, dynamic>.from(_messages[index].toolResults ?? {'fileEdits': <dynamic>[]});
          tr['fileEdits'] = fileEdits;
          // Collapse thoughts when tools start (end of thinking phase)
          final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
          ui['expandThoughts'] = false;
          tr['ui'] = ui;
          _messages[index] = _messages[index].copyWith(toolResults: tr);
          notifyListeners();
          break;
    case 'tool_result': {
          final name = evt['name'] as String?;
          final result = evt['result'];
          if (name == 'read_file' && result is Map && (result['status'] == 'success')) {
            filesRead.add({
              'path': result['path'],
              'lines': result['lines'],
            });
      final tr = Map<String, dynamic>.from(_messages[index].toolResults ?? {'fileEdits': fileEdits});
            tr['filesRead'] = List<Map<String, dynamic>>.from(filesRead);
      final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
      ui['expandThoughts'] = false;
      tr['ui'] = ui;
            _messages[index] = _messages[index].copyWith(toolResults: tr);
            notifyListeners();
          } else if (name == 'search' && result is Map && (result['status'] == 'success')) {
            filesSearched.add({
              'query': result['query'],
              'results': result['results'],
            });
      final tr = Map<String, dynamic>.from(_messages[index].toolResults ?? {'fileEdits': fileEdits});
            tr['filesSearched'] = List<Map<String, dynamic>>.from(filesSearched);
      final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
      ui['expandThoughts'] = false;
      tr['ui'] = ui;
            _messages[index] = _messages[index].copyWith(toolResults: tr);
            notifyListeners();
          }
          break;
        }
        case 'error':
          _messages[index] = _messages[index].copyWith(
            messageType: AgentMessageType.error,
            content: 'Sorry, an error occurred: ${evt['message']}',
          );
          notifyListeners();
          break;
        case 'end':
          // apply final fileEdits bundle if provided
          if (evt['fileEdits'] is List) {
            fileEdits.clear();
            fileEdits.addAll(evt['fileEdits']);
            final tr = Map<String, dynamic>.from(_messages[index].toolResults ?? {});
            tr['fileEdits'] = fileEdits;
            final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
            ui['expandThoughts'] = false; // ensure collapse after end
            tr['ui'] = ui;
            _messages[index] = _messages[index].copyWith(toolResults: tr);
          }
          break;
      }
    }

  // Persist and refresh after stream completes
    await _client.from('agent_chat_messages').insert(userMessage.toMap());
    // Persist AI message with `thoughts`
    final aiToSave = _messages[index].copyWith(
      thoughts: thoughtsBuf.isNotEmpty ? thoughtsBuf.toString() : _messages[index].thoughts,
    );
    // Strip UI-only keys before saving
    final sanitized = aiToSave.copyWith(
      toolResults: () {
        final tr = aiToSave.toolResults;
        if (tr == null) return null;
        final m = Map<String, dynamic>.from(tr);
        m.remove('ui');
        return m;
      }(),
    );
    await _client.from('agent_chat_messages').insert(sanitized.toMap());
    _ref.read(projectFilesProvider(projectId).notifier).fetchFiles();

    _isStreaming = false;
    notifyListeners();
  }
}
