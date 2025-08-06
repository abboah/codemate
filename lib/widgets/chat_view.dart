import 'dart:async';
import 'package:codemate/models/chat_models.dart';
import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/widgets/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatView extends ConsumerStatefulWidget {
  final Topic topic;
  final Enrollment enrollment;
  final List<TopicNote> notes;
  final TopicChat? chat;
  final Function(TopicChat) onNewChatStarted;

  const ChatView({
    super.key,
    required this.topic,
    required this.enrollment,
    required this.notes,
    required this.chat,
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
  String _selectedModel = 'gemini-1.5-flash-latest';

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
        _buildHeader(),
        Expanded(
          child: (widget.chat == null && _messages.isEmpty)
              ? _buildNewChatView()
              : _buildExistingChatView(),
        ),
        _buildMessageInputField(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Make header transparent and remove border
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PopupMenuButton<String>(
            initialValue: _selectedModel,
            onSelected: (String model) {
              setState(() {
                _selectedModel = model;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'gemini-1.5-flash-latest',
                child: ListTile(
                  leading: Icon(Icons.flash_on),
                  title: Text('Robin basic'),
                  subtitle: Text('Great for most tasks'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'gemini-2.5-flash',
                child: ListTile(
                  leading: Icon(Icons.star),
                  title: Text('Robin +'),
                  subtitle: Text('For more advanced use cases'),
                ),
              ),
            ],
            child: Row(
              children: [
                Text(
                  _selectedModel == 'gemini-1.5-flash-latest' ? 'Robin basic' : 'Robin +',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewChatView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white38),
          SizedBox(height: 16),
          Text(
            'Ask Robin anything about this topic.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExistingChatView() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isLastAiMessage = index == _messages.length - 1 && message.sender == 'ai';
              
              return Column(
                crossAxisAlignment: message.sender == 'user' 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  ChatMessageBubble(message: message),
                  if (isLastAiMessage && !_isSending)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                        tooltip: 'Copy Message',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard!')),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800), // Center and constrain width
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 16),
            _isSending
                ? const CircularProgressIndicator()
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: _sendMessage,
                  ),
          ],
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
    
    final stream = ref.read(dynamicGeminiProvider(_selectedModel)).generateContentStream([Content.text(prompt)]);
    
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
    final stream = ref.read(dynamicGeminiProvider(_selectedModel)).generateContentStream([Content.text(prompt)]);

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