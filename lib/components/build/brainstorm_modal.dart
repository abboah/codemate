import 'dart:async';
import 'dart:ui';
import 'package:codemate/components/build/project_confirmation_modal.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:codemate/services/project_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatMessage {
  final String sender;
  String content;
  final bool isUser;

  ChatMessage(this.sender, this.content, {this.isUser = false});

  Content toContent() {
    return Content(isUser ? 'user' : 'model', [TextPart(content)]);
  }
}

class ProjectAnalysis {
  String projectTitle;
  String description;
  List<String> suggestedStack;
  List<String> coreFeatures;

  ProjectAnalysis({
    required this.projectTitle,
    required this.description,
    required this.suggestedStack,
    required this.coreFeatures,
  });

  ProjectAnalysis.copy(ProjectAnalysis other)
      : projectTitle = other.projectTitle,
        description = other.description,
        suggestedStack = List.from(other.suggestedStack),
        coreFeatures = List.from(other.coreFeatures);

  factory ProjectAnalysis.fromJson(Map<String, dynamic> json) {
    return ProjectAnalysis(
      projectTitle: json['projectTitle'] ?? 'Untitled Project',
      description: json['description'] ?? '',
      suggestedStack: List<String>.from(json['suggestedStack'] ?? []),
      coreFeatures: List<String>.from(json['coreFeatures'] ?? []),
    );
  }
}

class BrainstormModal extends ConsumerStatefulWidget {
  const BrainstormModal({super.key});

  @override
  _BrainstormModalState createState() => _BrainstormModalState();
}

class _BrainstormModalState extends ConsumerState<BrainstormModal> {
  final ChatService _chatService = ChatService();
  final ProjectAnalysisService _analysisService = ProjectAnalysisService();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
        'ai', 'Hello! What project are you thinking of building today?')
  ];
  bool _isSending = false;
  bool _isAnalyzing = false;
  String? _sessionId;
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    final initialInput = _messages.first.content;
    final sessionId = await ref
        .read(projectsProvider)
        .startPlanningSession('brainstorm', initialInput);
    setState(() {
      _sessionId = sessionId;
    });
  }

  void _sendMessage() {
    if (_textController.text.isEmpty || _sessionId == null) return;
    final messageText = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add(ChatMessage('user', messageText, isUser: true));
      _isSending = true;
    });

    final history = _messages.map((m) => m.toContent()).toList();
    final aiResponse = ChatMessage('ai', '', isUser: false);
    _messages.add(aiResponse);

    const systemInstruction =
        'You are Robin, an expert AI software development assistant. '
        'Your goal is to help users brainstorm and define a new software project. '
        'Ask clarifying questions about their goals, target audience, and core features. '
        'Guide them towards a clear project concept. Keep your responses concise and encouraging.';

    _streamSubscription = _chatService
        .sendMessage(messageText, history, systemInstruction)
        .listen((chunk) {
      setState(() {
        aiResponse.content += chunk;
      });
    }, onDone: () {
      setState(() {
        _isSending = false;
      });
    }, onError: (e) {
      setState(() {
        aiResponse.content = 'Error: Could not connect to the AI.';
        _isSending = false;
      });
    });
  }

  Future<void> _wrapUp() async {
    if (_sessionId == null) return;
    setState(() => _isAnalyzing = true);

    final conversationText =
        _messages.map((m) => '${m.sender}: ${m.content}').join('\n');

    try {
      final analysis =
          await _analysisService.analyzeDescription(conversationText);

      await ref
          .read(projectsProvider)
          .updatePlanningSession(_sessionId!, analysis);

      if (!mounted) return;

      final newProjectId = await showDialog<String>(
        context: context,
        builder: (context) => ProjectConfirmationModal(
            analysis: analysis, sessionId: _sessionId!),
      );

      if (!mounted) return;

      if (newProjectId != null) {
        Navigator.of(context).pop(newProjectId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze project: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog.fullscreen(
        backgroundColor: Colors.black.withOpacity(0.5),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Brainstorm Your Project'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (_messages.length > 2)
                TextButton.icon(
                  onPressed: _isAnalyzing ? null : _wrapUp,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Wrap Up'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return MessageBubble(message: message);
                  },
                ),
              ),
              ChatInputField(
                controller: _textController,
                isSending: _isSending,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              isUser ? null : Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Text(
                message.content,
                style: GoogleFonts.poppins(color: Colors.white, height: 1.5),
              ),
      ),
    );
  }
}

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30.0),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20.0),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: onSend,
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}