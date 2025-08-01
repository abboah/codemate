import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

// ... app stuff here

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: LlmChatView(
          provider: GeminiProvider(
            model: GenerativeModel(
              model: 'gemini-2.0-flash',
              apiKey: 'GEMINI-API-KEY',
              systemInstruction: Content.text(
                'You are a helpful AI assistant. Always be polite, concise, and accurate in your responses. '
                'If you don\'t know something, admit it rather than making up information.'
              ),
            ),
          ),
        ),
      );
}

// Alternative: Using Content.multi for more complex system instructions
class ChatPageAdvanced extends StatelessWidget {
  const ChatPageAdvanced({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: LlmChatView(
          provider: GeminiProvider(
            model: GenerativeModel(
              model: 'gemini-2.0-flash',
              apiKey: 'GEMINI-API-KEY',
              systemInstruction: Content.multi([
                TextPart('You are a Flutter development assistant.'),
                TextPart('Always provide code examples when explaining Flutter concepts.'),
                TextPart('Focus on best practices and modern Flutter patterns.'),
              ]),
            ),
          ),
        ),
      );
}

// Example with role-specific system prompt
class CustomerSupportChatPage extends StatelessWidget {
  const CustomerSupportChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Customer Support')),
        body: LlmChatView(
          provider: GeminiProvider(
            model: GenerativeModel(
              model: 'gemini-2.0-flash',
              apiKey: 'GEMINI-API-KEY',
              systemInstruction: Content.text(
                'You are a customer support representative for a mobile app company. '
                'Be empathetic, solution-oriented, and professional. '
                'Always try to resolve issues step-by-step and ask clarifying questions when needed. '
                'If you cannot solve a problem, escalate appropriately.'
              ),
            ),
          ),
        ),
      );
}