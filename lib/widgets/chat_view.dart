import 'dart:async';
import 'package:codemate/models/chat_models.dart';
import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui';

const Color seaBlue = Color(0xFF006994);

class ChatView extends ConsumerStatefulWidget {
  final Topic topic;
  final Enrollment enrollment;
  final List<TopicNote> notes;
  final TopicChat? chat;
  final String selectedModel;
  final Function(TopicChat) onNewChatStarted;

  const ChatView({
    super.key,
    required this.topic,
    required this.enrollment,
    required this.notes,
    required this.chat,
    required this.selectedModel,
    required this.onNewChatStarted,
  });

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.chat != null) {
      _loadInitialMessages();
    }
  }

  void _loadInitialMessages() async {
    setState(() => _isLoading = true);
    final messages = await ref.read(chatMessagesProvider(widget.chat!.id).future);
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header is now in the parent TopicChatModal
        Expanded(
          child: (widget.chat == null && _messages.isEmpty)
              ? _buildNewChatView()
              : _buildExistingChatView(),
        ),
        _buildMessageInputField(),
      ],
    );
  }

  Widget _buildNewChatView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: seaBlue.withOpacity(0.8)),
          const SizedBox(height: 24),
          Text(
            'Ask Robin anything about\n${widget.topic.title}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation below.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExistingChatView() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: seaBlue))
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isLastAiMessage = index == _messages.length - 1 && message.sender == 'ai';
              
              return ChatMessageBubble(
                message: message,
                isLastAiMessage: isLastAiMessage && !_isSending,
              );
            },
          );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask a follow-up...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: seaBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      chatId: widget.chat?.id ?? 'new',
      sender: 'user',
      content: messageText,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    try {
      if (widget.chat == null) {
        await _handleNewChat(userMessage);
      } else {
        await _handleExistingChat(userMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleNewChat(ChatMessage userMessage) async {
    final notesContext = widget.notes.map((n) => '## ${n.title}\n${n.content}').join('\n\n');
    final prompt = """
      You are a helpful AI assistant named Robin. A user is starting a new chat to ask about the topic: "${widget.topic.title}".
      Use the following notes as the primary context for your answer.
      --- TOPIC NOTES ---
      $notesContext
      --- END NOTES ---
      The user's first message is: "${userMessage.content}"
      Your response:
    """;
    
    final stream = ref.read(dynamicGeminiProvider(widget.selectedModel)).generateContentStream([Content.text(prompt)]);
    
    final aiMessage = ChatMessage(
      id: _uuid.v4(),
      chatId: 'new',
      sender: 'ai',
      content: '',
      sentAt: DateTime.now(),
    );
    setState(() {
      _messages.add(aiMessage);
    });

    StringBuffer contentBuffer = StringBuffer();
    await for (var chunk in stream) {
      contentBuffer.write(chunk.text);
      setState(() {
        _messages.last = ChatMessage(
          id: aiMessage.id,
          chatId: aiMessage.chatId,
          sender: 'ai',
          content: contentBuffer.toString(),
          sentAt: aiMessage.sentAt,
        );
      });
      _scrollToBottom();
    }

    final newChat = await ref.read(createTopicChatProvider({
      'enrollment': widget.enrollment,
      'topic': widget.topic,
      'message': userMessage.content,
      'aiResponse': contentBuffer.toString(),
    }).future);

    widget.onNewChatStarted(newChat);
  }

  Future<void> _handleExistingChat(ChatMessage userMessage) async {
    await ref.read(sendMessageProvider)({
      'chatId': widget.chat!.id,
      'sender': 'user',
      'content': userMessage.content,
    });

    final history = _messages.map((m) => '${m.sender}: ${m.content}').join('\n');
    final prompt = """
      You are a helpful AI assistant named Robin. Continue the following conversation.
      The user is asking about a specific topic, so use the provided context to answer.
      --- CONVERSATION HISTORY ---
      $history
      --- END HISTORY ---
      Your response:
    """;
    final stream = ref.read(dynamicGeminiProvider(widget.selectedModel)).generateContentStream([Content.text(prompt)]);

    final aiMessage = ChatMessage(
      id: _uuid.v4(),
      chatId: widget.chat!.id,
      sender: 'ai',
      content: '',
      sentAt: DateTime.now(),
    );
    setState(() {
      _messages.add(aiMessage);
    });

    StringBuffer contentBuffer = StringBuffer();
    await for (var chunk in stream) {
      contentBuffer.write(chunk.text);
      setState(() {
        _messages.last = ChatMessage(
          id: aiMessage.id,
          chatId: aiMessage.chatId,
          sender: 'ai',
          content: contentBuffer.toString(),
          sentAt: aiMessage.sentAt,
        );
      });
      _scrollToBottom();
    }

    await ref.read(sendMessageProvider)({
      'chatId': widget.chat!.id,
      'sender': 'ai',
      'content': contentBuffer.toString(),
    });
  }
}