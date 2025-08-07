import 'package:codemate/models/chat_models.dart';
import 'package:codemate/widgets/code_block_builder.dart';
import 'package:codemate/widgets/inline_code_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

const Color seaBlue = Color(0xFF006994);

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isLastAiMessage;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.isLastAiMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const CircleAvatar(
              backgroundColor: Colors.black26,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isUser ? seaBlue : Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: MarkdownBody(
                    data: message.content,
                    selectable: true,
                    builders: {
                      'pre': CodeBlockBuilder(),
                      'code': InlineCodeBuilder(),
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                      h1: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      h2: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      h3: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      code: GoogleFonts.robotoMono(backgroundColor: Colors.black.withOpacity(0.2), color: Colors.white),
                    ),
                  ),
                ),
                if (isLastAiMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 8),
                    child: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                      tooltip: 'Copy Message',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard!'),
                            backgroundColor: seaBlue,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser)
            const CircleAvatar(
              backgroundColor: Colors.black26,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
        ],
      ),
    );
  }
}