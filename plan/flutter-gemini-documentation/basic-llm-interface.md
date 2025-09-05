In addition to the features that are provided automatically by the LlmChatView, a number of integration points allow your app to blend seamlessly with other features to provide additional functionality:

Welcome messages: Display an initial greeting to users.
Suggested prompts: Offer users predefined prompts to guide interactions.
System instructions: Provide the LLM with specific input to influence its responses.
Disable attachments and audio input: Remove optional parts of the chat UI.
Manage cancel or error behavior: Change the user cancellation or LLM error behavior.
Manage history: Every LLM provider allows for managing chat history, which is useful for clearing it, changing it dynamically and storing it between sessions.
Chat serialization/deserialization: Store and retrieve conversations between app sessions.
Custom response widgets: Introduce specialized UI components to present LLM responses.
Custom styling: Define unique visual styles to match the chat appearance to the overall app.
Chat w/o UI: Interact directly with the LLM providers without affecting the user's current chat session.
Custom LLM providers: Build your own LLM provider for integration of chat with your own model backend.
Rerouting prompts: Debug, log, or reroute messages meant for the provider to track down issues or route prompts dynamically.

You can initialize the LlmChatView with a welcome message by setting the welcomeMessage parameter:

```dart
class ChatPage extends StatelessWidget {
 const ChatPage({super.key});

 @override
 Widget build(BuildContext context) => Scaffold(
       appBar: AppBar(title: const Text(App.title)),
       body: LlmChatView(
         welcomeMessage: 'Hello and welcome to the Flutter AI Toolkit!',
         provider: GeminiProvider(
           model: GenerativeModel(
             model: 'gemini-2.0-flash',
             apiKey: geminiApiKey,
           ),
         ),
       ),
     );
}
```

The suggestions are only shown when there is no existing chat history. Clicking one copies the text into the user's prompt editing area. To set the list of suggestions, construct the LlmChatView with the suggestions parameter:

```dart
class ChatPage extends StatelessWidget {
 const ChatPage({super.key});

 @override
 Widget build(BuildContext context) => Scaffold(
       appBar: AppBar(title: const Text(App.title)),
       body: LlmChatView(
         suggestions: [
           'I\'m a Star Wars fan. What should I wear for Halloween?',
           'I\'m allergic to peanuts. What candy should I avoid at Halloween?',
           'What\'s the difference between a pumpkin and a squash?',
         ],
         provider: GeminiProvider(
           model: GenerativeModel(
             model: 'gemini-2.0-flash',
             apiKey: geminiApiKey,
           ),
         ),
       ),
     );
}
```


## LLM INstructions

To optimize an LLM's responses based on the needs of your app, you'll want to give it instructions. For example, the recipes example app uses the systemInstructions parameter of the GenerativeModel class to tailor the LLM to focus on delivering recipes based on the user's instructions:

```dart
class _HomePageState extends State<HomePage> {
  ...
  // create a new provider with the given history and the current settings
  LlmProvider _createProvider([List<ChatMessage>? history]) => GeminiProvider(
      history: history,
        ...,
        model: GenerativeModel(
          model: 'gemini-2.0-flash',
          apiKey: geminiApiKey,
          ...,
          systemInstruction: Content.system('''
You are a helpful assistant that generates recipes based on the ingredients and 
instructions provided as well as my food preferences, which are as follows:
{Settings.foodPreferences.isEmpty ? 'I don\'t have any food preferences' : Settings.foodPreferences}

You should keep things casual and friendly. You may generate multiple recipes in a single response, but only if asked. ...
''',
          ),
        ),
      );
  ...
}
```