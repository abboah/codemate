import 'dart:async';
import 'dart:ui';
import 'package:codemate/components/build/project_confirmation_modal.dart';
import 'package:codemate/services/chat_service.dart';
import 'package:codemate/services/project_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const Color seaBlue = Color(0xFF006994);

// Note: These models are local to the brainstorming flow and are not saved to the DB.
class BrainstormChatMessage {
  final String sender;
  String content;
  final bool isUser;

  BrainstormChatMessage(this.sender, this.content, {this.isUser = false});

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
  final List<BrainstormChatMessage> _messages = [
    BrainstormChatMessage(
        'ai', 'Hello! What project are you thinking of building today?')
  ];
  bool _isSending = false;
  bool _isAnalyzing = false;
  StreamSubscription<String>? _streamSubscription;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.isEmpty) return;
    final messageText = _textController.text;
    _textController.clear();

    setState(() {
      _messages.add(BrainstormChatMessage('user', messageText, isUser: true));
      _isSending = true;
      // Add a placeholder for the AI response
      _messages.add(BrainstormChatMessage('ai', '', isUser: false));
    });

    final history =
        _messages.map((m) => m.toContent()).toList()..removeLast();

    const systemInstruction =
        'You are Robin, an expert AI software development assistant. '
        'Your goal is to help users brainstorm and define a new software project. '
        'Ask clarifying questions about their goals, target audience, and core features. '
        'Guide them towards a clear project concept. Keep your responses concise and encouraging.';

    _streamSubscription = _chatService
        .sendMessage(messageText, history, systemInstruction)
        .listen((chunk) {
      setState(() {
        _messages.last.content += chunk;
      });
    }, onDone: () {
      setState(() {
        _isSending = false;
      });
    }, onError: (e) {
      setState(() {
        _messages.last.content = 'Error: Could not connect to the AI.';
        _isSending = false;
      });
    });
  }

  Future<void> _wrapUpAndAnalyze() async {
    setState(() => _isAnalyzing = true);

    final conversationText =
        _messages.map((m) => '${m.sender}: ${m.content}').join('\n');

    try {
      final analysis =
          await _analysisService.analyzeDescription(conversationText);

      if (!mounted) return;

      // The confirmation modal will handle project creation
      final newProjectId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            ProjectConfirmationModal(analysis: analysis),
      );

      if (mounted && newProjectId != null) {
        // Pop the brainstorm modal and pass the new project ID back
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
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Brainstorm New Project',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              if (_messages.length > 2)
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _wrapUpAndAnalyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'Analyze & Create',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: seaBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final BrainstormChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(Icons.lightbulb_outline, size: 20, color: Colors.white70),
            ),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isUser ? seaBlue : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser)
            const CircleAvatar(
              backgroundColor: seaBlue,
              child: Icon(Icons.person_outline, size: 20, color: Colors.white),
            ),
        ],
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
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe your project idea...',
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20.0),
                    ),
                    onSubmitted: isSending ? null : (_) => onSend(),
                  ),
                ),
                isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            )),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, color: seaBlue),
                        iconSize: 28,
                        tooltip: 'Send Message',
                        onPressed: onSend,
                      ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}