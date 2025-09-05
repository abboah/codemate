Get started
Installation

Add the following dependencies to your pubspec.yaml file:

```yaml
dependencies:
  flutter_ai_toolkit: ^latest_version
  google_generative_ai: ^latest_version # you might choose to use Gemini,
  firebase_core: ^latest_version        # or Vertex AI or both
```
# Gemini AI configuration

The toolkit supports both Google Gemini AI and Firebase Vertex AI as LLM providers. To use Google Gemini AI, obtain an API key from Gemini AI Studio. Be careful not to check this key into your source code repository to prevent unauthorized access.

You'll also need to choose a specific Gemini model name to use in creating an instance of the Gemini model. The following example uses gemini-2.0-flash, but you can choose from an ever-expanding set of models.

```dart
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
            ),
          ),
        ),
      );
}
```

The GenerativeModel class comes from the google_generative_ai package. The AI Toolkit builds on top of this package with the GeminiProvider, which plugs Gemini AI into the LlmChatView, the top-level widget that provides an LLM-based chat conversation with your users.

