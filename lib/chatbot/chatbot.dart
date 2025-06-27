import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:codemate/chatbot/chat_history.dart';
import 'package:codemate/layouts/background_pattern.dart';
import 'package:codemate/layouts/nav_section.dart';
import 'package:codemate/layouts/top_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/nav_provider.dart';
import '../providers/chat_history_provider.dart';
import '../layouts/desktop_sidebar.dart';

class ChatMessage {
  final String text;
  final bool isUserMessage;
  final DateTime timestamp;
  final bool isStreaming;

  ChatMessage({
    required this.text,
    required this.isUserMessage,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    bool? isUserMessage,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUserMessage: isUserMessage ?? this.isUserMessage,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class CodeBlock {
  final String language;
  final String code;
  final int startIndex;
  final int endIndex;

  CodeBlock({
    required this.language,
    required this.code,
    required this.startIndex,
    required this.endIndex,
  });
}

class Chatbot extends ConsumerStatefulWidget {
  const Chatbot({super.key});

  @override
  ConsumerState<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends ConsumerState<Chatbot> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  // Replace with your actual Gemini API key
  final String _apiKey = 'AIzaSyCOOB62Ru855vTalNVIun15iZZokipcjEY';
  bool _isLoading = false;
  StreamSubscription<String>? _streamSubscription;

  // For streaming text
  String _currentStreamingText = '';
  int _currentStreamingIndex = -1;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(selectedNavIndexProvider.notifier).state = 3,
    );

    _messages.add(
      ChatMessage(
        text: "Hello! I'm Robin, your AI assistant. How can I help you today?",
        isUserMessage: false,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  List<CodeBlock> _extractCodeBlocks(String text) {
    final List<CodeBlock> codeBlocks = [];
    final RegExp codeBlockRegex = RegExp(
      r'```(\w+)?\n([\s\S]*?)```',
      multiLine: true,
    );
    final Iterable<RegExpMatch> matches = codeBlockRegex.allMatches(text);

    for (final match in matches) {
      final String language = match.group(1)?.toLowerCase() ?? 'plaintext';
      final String code = match.group(2) ?? '';
      codeBlocks.add(
        CodeBlock(
          language: language,
          code: code.trim(),
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    return codeBlocks;
  }

  String _getLanguageDisplayName(String language) {
    const Map<String, String> languageMap = {
      'js': 'JavaScript',
      'javascript': 'JavaScript',
      'ts': 'TypeScript',
      'typescript': 'TypeScript',
      'py': 'Python',
      'python': 'Python',
      'java': 'Java',
      'cpp': 'C++',
      'c++': 'C++',
      'c': 'C',
      'cs': 'C#',
      'csharp': 'C#',
      'php': 'PHP',
      'rb': 'Ruby',
      'ruby': 'Ruby',
      'go': 'Go',
      'rs': 'Rust',
      'rust': 'Rust',
      'swift': 'Swift',
      'kt': 'Kotlin',
      'kotlin': 'Kotlin',
      'dart': 'Dart',
      'html': 'HTML',
      'css': 'CSS',
      'scss': 'SCSS',
      'sass': 'Sass',
      'json': 'JSON',
      'xml': 'XML',
      'yaml': 'YAML',
      'yml': 'YAML',
      'md': 'Markdown',
      'markdown': 'Markdown',
      'sql': 'SQL',
      'sh': 'Shell',
      'bash': 'Bash',
      'zsh': 'Zsh',
      'powershell': 'PowerShell',
      'dockerfile': 'Dockerfile',
      'plaintext': 'Plain Text',
    };

    return languageMap[language] ?? language.toUpperCase();
  }

  // Simulate streaming for regular HTTP response
  Stream<String> _simulateStreaming(String fullText) async* {
    const int chunkSize = 3;
    const Duration delay = Duration(milliseconds: 30);

    for (int i = 0; i < fullText.length; i += chunkSize) {
      await Future.delayed(delay);
      yield fullText.substring(0, i + chunkSize);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    String userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.insert(0, ChatMessage(text: userMessage, isUserMessage: true));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': userMessage},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2000,
            'topP': 0.8,
            'topK': 10,
          },
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final aiResponse =
            responseBody['candidates'][0]['content']['parts'][0]['text'];

        // Add streaming message
        setState(() {
          _messages.insert(
            0,
            ChatMessage(text: '', isUserMessage: false, isStreaming: true),
          );
          _currentStreamingIndex = 0;
          _isLoading = false;
        });

        // Start streaming simulation
        _streamSubscription = _simulateStreaming(aiResponse).listen(
          (streamedText) {
            setState(() {
              _currentStreamingText = streamedText;
              _messages[_currentStreamingIndex] =
                  _messages[_currentStreamingIndex].copyWith(
                    text: streamedText,
                  );
            });
            _scrollToBottom();
          },
          onDone: () {
            setState(() {
              _messages[_currentStreamingIndex] =
                  _messages[_currentStreamingIndex].copyWith(
                    isStreaming: false,
                  );
              _currentStreamingIndex = -1;
              _currentStreamingText = '';
            });
          },
          onError: (error) {
            setState(() {
              _messages[_currentStreamingIndex] =
                  _messages[_currentStreamingIndex].copyWith(
                    text: 'Error occurred during streaming.',
                    isStreaming: false,
                  );
              _currentStreamingIndex = -1;
              _currentStreamingText = '';
            });
          },
        );
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            text: 'Sorry, I encountered an error. Please try again later.',
            isUserMessage: false,
          ),
        );
        _isLoading = false;
      });
      print('Error: $e');
    }
  }

  void _saveChatToHistory() {
    if (_messages.length > 1) {
      ref
          .read(chatHistoryProvider.notifier)
          .addChat(_messages.reversed.toList());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  double _getChatWidth(BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return (MediaQuery.sizeOf(context).width * 0.35) +
          40; // Input width + 40px
    } else {
      return (MediaQuery.sizeOf(context).width * 0.9) +
          20; // Input width + 20px
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final chatTitles = [
      'Chat with Copilot',
      'Project Help',
      'Debug Session',
      'General Q&A',
    ];

    return Scaffold(
      body: Stack(
        children: [
          Container(
            // decoration: const BoxDecoration(
            //   gradient: LinearGradient(
            //     begin: Alignment.topLeft,
            //     end: Alignment.bottomRight,
            //     colors: [
            //       Color(0xFF0F0F23),
            //       Color(0xFF1A1A2E),
            //       Color(0xFF16213E),
            //     ],
            //   ),
            // ),
            child: Stack(
              children: [
                _buildBackgroundPattern(),
                SafeArea(
                  child: Column(
                    children: [
                      TopAppbar(isDesktop: isDesktop),
                      Expanded(
                        child: Row(
                          children: [
                            if (isDesktop)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: DesktopSidebar(),
                              ),
                            Expanded(
                              child: _buildChatScreen(context, isDesktop),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(painter: BackgroundPatternPainter()),
    );
  }

  Widget _buildChatScreen(BuildContext context, bool isDesktop) {
    final chatHistory = ref.watch(chatHistoryProvider);
    final chatTitles =
        chatHistory.isEmpty
            ? [
              'Chat with Copilot',
              'Project Help',
              'Debug Session',
              'General Q&A',
            ]
            : chatHistory
                .map(
                  (chat) =>
                      chat.isNotEmpty
                          ? chat.last.text.substring(0, 30)
                          : 'Untitled',
                )
                .toList();

    return Container(
      height: MediaQuery.sizeOf(context).height,
      width: MediaQuery.sizeOf(context).width,
      margin: EdgeInsets.only(right: 16, bottom: 16, left: isDesktop ? 0 : 16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: _getChatWidth(context, isDesktop),
                      child:
                          _messages.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.all(16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  return _buildMessageBubble(_messages[index]);
                                },
                              ),
                    ),
                  ),
                ),

                if (_isLoading)
                  Container(
                    width: _getChatWidth(context, isDesktop),
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.8),
                                    Colors.purple.withOpacity(0.8),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Robin',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.only(left: 40),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.blue.withOpacity(0.8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Thinking...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width:
                            isDesktop
                                ? MediaQuery.sizeOf(context).width * 0.35
                                : MediaQuery.sizeOf(context).width * 0.9,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _messageController,
                              maxLines: null,
                              cursorColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Ask Robin...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              onFieldSubmitted: (_) => _sendMessage(),
                              enabled: !_isLoading,
                            ),
                            Row(
                              children: [
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(
                                    Icons.attach_file,
                                    color: Colors.white,
                                  ),
                                  onPressed: _isLoading ? null : () {},
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.electric_bolt_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _isLoading ? null : () {},
                                ),
                                const Spacer(),
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color:
                                        _isLoading
                                            ? Colors.grey.withOpacity(0.5)
                                            : Colors.blue.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _isLoading ? null : _sendMessage,
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 0,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.blue.withOpacity(0.5),
                    child: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      _saveChatToHistory();
                      _streamSubscription?.cancel();
                      setState(() {
                        _messages.clear();
                        _currentStreamingIndex = -1;
                        _currentStreamingText = '';
                        _messages.add(
                          ChatMessage(
                            text:
                                "Hello! I'm Robin, your AI assistant. How can I help you today?",
                            isUserMessage: false,
                          ),
                        );
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          ChatHistorySidebar(chatTitles: chatTitles),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start a conversation with Robin',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything and I\'ll help you out!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isUserMessage) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth:
                _getChatWidth(
                  context,
                  MediaQuery.of(context).size.width > 1200,
                ) *
                0.8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.8),
                Colors.blue.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      );
    } else {
      return _buildAIMessageBubble(message);
    }
  }

  Widget _buildAIMessageBubble(ChatMessage message) {
    final codeBlocks = _extractCodeBlocks(message.text);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar and Name
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withOpacity(0.8),
                        Colors.purple.withOpacity(0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Robin',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!message.isStreaming)
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                if (message.isStreaming)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          // Message Content
          Container(
            padding: const EdgeInsets.only(left: 40),
            child: _buildMessageContent(
              message.text,
              codeBlocks,
              message.isStreaming,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(
    String text,
    List<CodeBlock> codeBlocks,
    bool isStreaming,
  ) {
    if (codeBlocks.isEmpty) {
      return SelectableText(
        text + (isStreaming ? '▊' : ''),
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
          height: 1.6,
          letterSpacing: 0.2,
        ),
      );
    }

    List<Widget> widgets = [];
    int currentIndex = 0;

    for (int i = 0; i < codeBlocks.length; i++) {
      final codeBlock = codeBlocks[i];

      // Add text before code block
      if (currentIndex < codeBlock.startIndex) {
        final beforeText = text.substring(currentIndex, codeBlock.startIndex);
        if (beforeText.trim().isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                beforeText.trim(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }
      }

      // Add code block
      widgets.add(_buildCodeBlock(codeBlock));
      widgets.add(const SizedBox(height: 16));

      currentIndex = codeBlock.endIndex;
    }

    // Add remaining text after last code block
    if (currentIndex < text.length) {
      final remainingText = text.substring(currentIndex);
      if (remainingText.trim().isNotEmpty) {
        widgets.add(
          SelectableText(
            remainingText.trim() + (isStreaming ? '▊' : ''),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildCodeBlock(CodeBlock codeBlock) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getLanguageDisplayName(codeBlock.language),
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: codeBlock.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Code copied to clipboard'),
                          backgroundColor: Colors.green.withOpacity(0.8),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                codeBlock.code,
                language: codeBlock.language,
                theme: vs2015Theme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'Fira Code',
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
