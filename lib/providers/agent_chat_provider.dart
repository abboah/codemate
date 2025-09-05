import 'dart:async';
import 'dart:convert';
import 'package:codemate/models/agent_chat_message.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:codemate/utils/ndjson_stream.dart';
import 'package:codemate/supabase_config.dart';

final chatServiceProvider = Provider((ref) => ChatService());

final projectChatsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      projectId,
    ) async {
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
  final ChatService _chatService; // kept for later use (title generation)
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
  StreamSubscription<String>?
  _streamSub; // reserved for future streaming control
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

      _messages =
          response.map((data) => AgentChatMessage.fromMap(data)).toList();
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
      final historyForBackend =
          _messages
              .where(
                (m) =>
                    m.id != userMessage.id &&
                    m.id != aiPlaceholder.id &&
                    m.messageType == AgentMessageType.text,
              )
              .map(
                (m) => {
                  "role": m.sender == MessageSender.user ? "user" : "model",
                  "parts": [
                    {"text": m.content},
                  ],
                },
              )
              .toList();

      final functionName =
          useAskHandler ? 'agent-chat-handler' : 'agent-handler';

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
      // Provide chatId so server can scope artifacts/messages correctly
      'chatId': chatId,
        },
      );

      if (response.status != 200) {
        throw Exception('Backend function failed: ${response.data}');
      }

      final Map<String, dynamic> result = response.data as Map<String, dynamic>;
      final aiResponseContent = result['text'] as String? ?? '';
      final List<dynamic> fileEdits = (result['fileEdits'] as List?) ?? [];
      final List<dynamic> filesAnalyzed = (result['filesAnalyzed'] as List?) ?? [];
      final List<dynamic> artifactIdsDyn = (result['artifactIds'] as List?) ?? const [];
      final List<String> artifactIds = artifactIdsDyn.map((e) => e.toString()).toList();
      // Prepare artifact refs for tool_results and tool_calls
      final List<Map<String, dynamic>> artifactRefs = [
        for (final id in artifactIds)
          {
            'name': 'artifact_read',
            'artifactId': id,
            'result': {'status': 'success', 'id': id},
          }
      ];

      // 3. Prepare the AI message for streaming and show tool results immediately
      final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if (index != -1) {
        _messages[index] = aiPlaceholder.copyWith(
          content: '',
          messageType: AgentMessageType.text,
          toolResults: {
            'fileEdits': fileEdits,
            if (filesAnalyzed.isNotEmpty) 'filesAnalyzed': filesAnalyzed,
            if (artifactRefs.isNotEmpty) 'artifacts': artifactRefs,
          },
          toolCalls: {
            'events': [
              // artifacts mapping
              for (int i = 0; i < artifactRefs.length; i++)
                {
                  'index': i + 1,
                  'name': artifactRefs[i]['name'],
                  'array': 'artifacts',
                  'offset': i,
                  'artifactId': artifactRefs[i]['artifactId'],
                },
              // filesAnalyzed mapping (indexes continue after artifacts)
              for (int j = 0; j < filesAnalyzed.length; j++)
                {
                  'index': artifactRefs.length + j + 1,
                  'name': 'analyze_document',
                  'array': 'filesAnalyzed',
                  'offset': j,
                },
            ]
          },
        );
        notifyListeners();

        // 4. Illusion streaming: gradually append text to placeholder
        const chunkSize = 24;
        for (int i = 0; i < aiResponseContent.length; i += chunkSize) {
          final end =
              (i + chunkSize < aiResponseContent.length)
                  ? i + chunkSize
                  : aiResponseContent.length;
          final current =
              _messages[index].content + aiResponseContent.substring(i, end);
          _messages[index] = _messages[index].copyWith(content: current);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 12));
        }
      }

      // 5. Persist messages to the database once complete (ensure AI sent_at > user sent_at)
      await _client.from('agent_chat_messages').insert(userMessage.toMap());
      final sentAtUser = userMessage.sentAt;
      final sentAtAi = sentAtUser.add(const Duration(milliseconds: 10));
  final aiWithToolResults = _messages[index].copyWith(sentAt: sentAtAi);
      final inserted = await _client
          .from('agent_chat_messages')
          .insert(aiWithToolResults.toMap())
          .select('id')
          .single();
      final String? aiMessageId = (inserted as Map<String, dynamic>?)?['id'] as String?;

      // Link any created artifacts to this AI message (and ensure chat_id)
      if (aiMessageId != null && artifactIds.isNotEmpty) {
        for (final aid in artifactIds) {
          try {
            await _client
                .from('agent_artifacts')
                .update({'message_id': aiMessageId, 'chat_id': chatId})
                .eq('id', aid);
          } catch (_) {}
        }
      }

      // 6. Refresh the file tree in case the agent modified files
      _ref.read(projectFilesProvider(projectId).notifier).fetchFiles();
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == aiPlaceholder.id);
      if (index != -1) {
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
    final historyForBackend =
        _messages
            .where(
              (m) =>
                  m.id != userMessage.id &&
                  m.id != aiPlaceholderId &&
                  m.messageType == AgentMessageType.text,
            )
            .map(
              (m) => {
                "role": m.sender == MessageSender.user ? "user" : "model",
                "parts": [
                  {"text": m.content},
                ],
              },
            )
            .toList();

    // Construct request to Supabase Edge Function (NDJSON stream)
    // Build Edge Functions URL from configured SUPABASE_URL
    final url = Uri.parse("${getFunctionsOrigin()}/$functionName");
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
      'history': historyForBackend,
      'projectId': projectId,
      'model': model,
      'attachedFiles': attachedFiles,
      'includeThoughts': true,
      // Provide chatId so server can scope artifacts/messages correctly
      'chatId': chatId,
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
      toolResults: {'fileEdits': <dynamic>[]},
    );
    notifyListeners();

  final fileEdits = <dynamic>[];
  final filesRead = <Map<String, dynamic>>[]; // { path, lines }
  final filesSearched = <Map<String, dynamic>>[]; // { query, results }
  // First-class artifacts captured during stream; entries: { name, artifactId?, result }
  final artifacts = <Map<String, dynamic>>[];
  // Composite tool executions captured during stream
  final compositeTasks = <Map<String, dynamic>>[];
  final toolCalls = <Map<String, dynamic>>[]; // { index, name, array, offset, artifactId? }
  final StringBuffer thoughtsBuf = StringBuffer();
  final List<String> createdArtifactIds = <String>[];

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
          final currentTR = Map<String, dynamic>.from(
            _messages[index].toolResults ?? {'fileEdits': fileEdits},
          );
          currentTR['ui'] = {
            ...(currentTR['ui'] as Map? ?? {}),
            'expandThoughts': true,
          };
          final currentThoughts = (_messages[index].thoughts ?? '') + delta;
          _messages[index] = _messages[index].copyWith(
            toolResults: currentTR,
            thoughts: currentThoughts,
          );
          notifyListeners();
          break;
        case 'text':
          final delta = evt['delta'] as String? ?? '';
          final current = _messages[index].content + delta;
          final tr = Map<String, dynamic>.from(
            _messages[index].toolResults ?? {'fileEdits': fileEdits},
          );
          // If thoughts have been streaming, keep expanded until tools start
          tr['ui'] = {...(tr['ui'] as Map? ?? {}), 'expandThoughts': true};
          _messages[index] = _messages[index].copyWith(
            content: current,
            toolResults: tr,
          );
          notifyListeners();
          break;
        case 'file_edit':
          fileEdits.add(evt);
          final tr = Map<String, dynamic>.from(
            _messages[index].toolResults ?? {'fileEdits': <dynamic>[]},
          );
          tr['fileEdits'] = fileEdits;
          // Collapse thoughts when tools start (end of thinking phase)
          final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
          ui['expandThoughts'] = false;
          tr['ui'] = ui;
          _messages[index] = _messages[index].copyWith(toolResults: tr);
          notifyListeners();
          break;
  case 'tool_result':
          {
            final name = evt['name'] as String?;
            final result = evt['result'];
            final id = evt['id'] as int?;
            if (name == 'read_file' &&
                result is Map &&
                (result['status'] == 'success')) {
              filesRead.add({'path': result['path'], 'lines': result['lines']});
              final tr = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {'fileEdits': fileEdits},
              );
              tr['filesRead'] = List<Map<String, dynamic>>.from(filesRead);
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = false;
              tr['ui'] = ui;
              _messages[index] = _messages[index].copyWith(toolResults: tr);
              notifyListeners();
              if (id != null) {
                toolCalls.add({
                  'index': id,
                  'name': 'read_file',
                  'array': 'filesRead',
                  'offset': filesRead.length - 1,
                });
                // Store tool call mapping in a separate field for UI rendering
                _messages[index] = _messages[index].copyWith(
                  toolResults: tr,
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
                notifyListeners();
              }
            } else if (name == 'search' &&
                result is Map &&
                (result['status'] == 'success')) {
              filesSearched.add({
                'query': result['query'],
                'results': result['results'],
              });
              final tr = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {'fileEdits': fileEdits},
              );
              tr['filesSearched'] = List<Map<String, dynamic>>.from(
                filesSearched,
              );
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = false;
              tr['ui'] = ui;
              _messages[index] = _messages[index].copyWith(toolResults: tr);
              notifyListeners();
              if (id != null) {
                toolCalls.add({
                  'index': id,
                  'name': 'search',
                  'array': 'filesSearched',
                  'offset': filesSearched.length - 1,
                });
                // Store tool call mapping in a separate field for UI rendering
                _messages[index] = _messages[index].copyWith(
                  toolResults: tr,
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
                notifyListeners();
              }
            } else if ((name == 'create_file' ||
                    name == 'update_file_content' ||
                    name == 'delete_file') &&
                result is Map &&
                (result['status'] == 'success')) {
              // File edit tools are already added to fileEdits via file_edit events,
              // but we need to capture the tool call mapping for inline rendering
              final tr = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {'fileEdits': fileEdits},
              );
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = false;
              tr['ui'] = ui;
              _messages[index] = _messages[index].copyWith(toolResults: tr);
              notifyListeners();
              if (id != null) {
                toolCalls.add({
                  'index': id,
                  'name': name,
                  'array': 'fileEdits',
                  'offset': fileEdits.length - 1,
                });
                // Store tool call mapping in a separate field for UI rendering
                _messages[index] = _messages[index].copyWith(
                  toolResults: tr,
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
                notifyListeners();
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
              final tr = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {'fileEdits': fileEdits},
              );
              tr['artifacts'] = List<Map<String, dynamic>>.from(artifacts);
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = false;
              tr['ui'] = ui;
              _messages[index] = _messages[index].copyWith(toolResults: tr);
              notifyListeners();
              if (id != null) {
                final call = <String, dynamic>{
                  'index': id,
                  'name': name,
                  'array': 'artifacts',
                  'offset': artifacts.length - 1,
                };
                if (artifactId != null) call['artifactId'] = artifactId;
                toolCalls.add(call);
                _messages[index] = _messages[index].copyWith(
                  toolResults: tr,
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
                notifyListeners();
              }
            } else if (name == 'implement_feature_and_update_todo') {
              // Capture composite tool results into tool_results.compositeTasks for persistence and inline mapping
              if (result is Map<String, dynamic>) {
                compositeTasks.add(Map<String, dynamic>.from(result));
                final tr = Map<String, dynamic>.from(
                  _messages[index].toolResults ?? {'fileEdits': fileEdits},
                );
                tr['compositeTasks'] = List<Map<String, dynamic>>.from(compositeTasks);
                // Collapse thoughts
                final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
                ui['expandThoughts'] = false;
                tr['ui'] = ui;
                _messages[index] = _messages[index].copyWith(toolResults: tr);
                notifyListeners();
                if (id != null) {
                  toolCalls.add({
                    'index': id,
                    'name': name,
                    'array': 'compositeTasks',
                    'offset': compositeTasks.length - 1,
                  });
                  _messages[index] = _messages[index].copyWith(
                    toolResults: tr,
                    toolCalls: <String, dynamic>{'events': toolCalls},
                  );
                  notifyListeners();
                }
              }
            } else if (name == 'analyze_document') {
              // Capture analyze_document results into tool_results.filesAnalyzed
              // Include both success and error payloads for debugging
              final tr = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {'fileEdits': fileEdits},
              );
              final filesAnalyzed = List<Map<String, dynamic>>.from(
                (tr['filesAnalyzed'] as List? ?? const []),
              );
              Map<String, dynamic> toAdd;
              if (result is Map) {
                toAdd = Map<String, dynamic>.from(result as Map);
              } else {
                toAdd = {'status': 'unknown', 'result': result};
              }
              bool isDup = false;
              final fu = (toAdd['file_url']?.toString() ?? '').trim();
              if (fu.isNotEmpty) {
                isDup = filesAnalyzed.any((e) => (e['file_url']?.toString() ?? '') == fu);
              } else {
                final mt = toAdd['mime_type']?.toString();
                final bl = toAdd['byte_length']?.toString();
                if (mt != null && bl != null) {
                  isDup = filesAnalyzed.any((e) => (e['mime_type']?.toString() == mt) && (e['byte_length']?.toString() == bl));
                }
              }
              if (!isDup) {
                filesAnalyzed.add(toAdd);
                tr['filesAnalyzed'] = filesAnalyzed;
              }
              final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
              ui['expandThoughts'] = false;
              tr['ui'] = ui;
              _messages[index] = _messages[index].copyWith(toolResults: tr);
              notifyListeners();
              if (id != null && !isDup) {
                toolCalls.add({
                  'index': id,
                  'name': name,
                  'array': 'filesAnalyzed',
                  'offset': filesAnalyzed.length - 1,
                });
                _messages[index] = _messages[index].copyWith(
                  toolResults: tr,
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
                notifyListeners();
              }
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
            final tr = Map<String, dynamic>.from(
              _messages[index].toolResults ?? {},
            );
            tr['fileEdits'] = fileEdits;
            final ui = Map<String, dynamic>.from((tr['ui'] as Map? ?? {}));
            ui['expandThoughts'] = false; // ensure collapse after end
            tr['ui'] = ui;
            _messages[index] = _messages[index].copyWith(toolResults: tr);
          }
          // merge any filesAnalyzed sent at end (server may batch these)
          if (evt['filesAnalyzed'] is List) {
            final tr = Map<String, dynamic>.from(
              _messages[index].toolResults ?? {},
            );
            final existing = List<Map<String, dynamic>>.from(
              (tr['filesAnalyzed'] as List? ?? const []),
            );
            final incoming = List<Map<String, dynamic>>.from(
              List<dynamic>.from(evt['filesAnalyzed']).map((e) => Map<String, dynamic>.from(e as Map)),
            );
            int addedCount = 0;
            for (final inc in incoming) {
              final fu = (inc['file_url']?.toString() ?? '').trim();
              bool dup = false;
              if (fu.isNotEmpty) {
                dup = existing.any((e) => (e['file_url']?.toString() ?? '') == fu);
              } else {
                final mt = inc['mime_type']?.toString();
                final bl = inc['byte_length']?.toString();
                if (mt != null && bl != null) {
                  dup = existing.any((e) => (e['mime_type']?.toString() == mt) && (e['byte_length']?.toString() == bl));
                }
              }
              if (!dup) {
                existing.add(inc);
                addedCount++;
              }
            }
            tr['filesAnalyzed'] = existing;
            // add synthetic toolCalls mapping for newly added items
            if (addedCount > 0) {
              final startOffset = existing.length - addedCount;
              for (int i = 0; i < addedCount; i++) {
                toolCalls.add({
                  'index': (toolCalls.length + 1),
                  'name': 'analyze_document',
                  'array': 'filesAnalyzed',
                  'offset': startOffset + i,
                });
              }
            }
            _messages[index] = _messages[index].copyWith(
              toolResults: tr,
              toolCalls: <String, dynamic>{'events': toolCalls},
            );
          }
          // capture artifactIds from server to link after saving message
          if (evt['artifactIds'] is List) {
            createdArtifactIds
              ..clear()
              ..addAll(List<dynamic>.from(evt['artifactIds']).map((e) => e.toString()));
            // Merge artifactIds into artifacts array and toolCalls
            if (artifacts.isNotEmpty) {
              for (int i = 0; i < artifacts.length && i < createdArtifactIds.length; i++) {
                final a = Map<String, dynamic>.from(artifacts[i]);
                a['artifactId'] ??= createdArtifactIds[i];
                artifacts[i] = a;
              }
              final tr2 = Map<String, dynamic>.from(
                _messages[index].toolResults ?? {},
              );
              tr2['artifacts'] = List<Map<String, dynamic>>.from(artifacts);
              final ui2 = Map<String, dynamic>.from((tr2['ui'] as Map? ?? {}));
              ui2['expandThoughts'] = false;
              tr2['ui'] = ui2;
              _messages[index] = _messages[index].copyWith(toolResults: tr2);
              if (toolCalls.isNotEmpty) {
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
                _messages[index] = _messages[index].copyWith(
                  toolCalls: <String, dynamic>{'events': toolCalls},
                );
              }
            }
          }
          break;
      }
    }

    // Persist and refresh after stream completes
    await _client.from('agent_chat_messages').insert(userMessage.toMap());
    // Persist AI message with `thoughts` and ensure ordering via sent_at
    final sentAtUser = userMessage.sentAt;
    final sentAtAi = sentAtUser.add(const Duration(milliseconds: 10));
    final aiToSave = _messages[index].copyWith(
      thoughts:
          thoughtsBuf.isNotEmpty
              ? thoughtsBuf.toString()
              : _messages[index].thoughts,
      toolCalls: <String, dynamic>{'events': toolCalls},
      sentAt: sentAtAi,
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
    final inserted = await _client
        .from('agent_chat_messages')
        .insert(sanitized.toMap())
        .select('id')
        .single();
    final String? aiMessageId = (inserted as Map<String, dynamic>?)?['id'] as String?;
    // Link artifacts created during this turn to the saved AI message
    if (aiMessageId != null && createdArtifactIds.isNotEmpty) {
      for (final aid in createdArtifactIds) {
        try {
          await _client
              .from('agent_artifacts')
              .update({'message_id': aiMessageId, 'chat_id': chatId})
              .eq('id', aid);
        } catch (_) {}
      }
    }
    _ref.read(projectFilesProvider(projectId).notifier).fetchFiles();

    _isStreaming = false;
    notifyListeners();
  }
}
