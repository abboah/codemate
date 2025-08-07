import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatService {
  Stream<String> sendMessage(
    String message,
    List<Content> history,
    String? systemInstruction, {
    String model = 'gemini-1.5-flash-latest', // Default model
  }) {
    final generativeModel = GenerativeModel(
      model: model,
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction:
          systemInstruction != null ? Content.system(systemInstruction) : null,
    );

    final content = Content.text(message);

    return generativeModel.generateContentStream(history..add(content)).map((response) {
      if (response.text == null) {
        return "I'm sorry, I didn't understand that. Could you please rephrase?";
      }
      return response.text!;
    });
  }

  Future<String> generateChatTitle(
      String userMessage, String aiResponse) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest', // Use a fast model for titles
      apiKey: dotenv.env['GEMINI_API_KEY']!,
      systemInstruction: Content.system(
          'You are a title generator. Create a short, concise title (5 words or less) for a conversation based on the first user message and the first AI response. Do not use quotes or any special characters.'),
    );

    final prompt =
        'User: "$userMessage"\nAI: "$aiResponse"\n\nGenerate a title for this conversation.';
    final response = await model.generateContent([Content.text(prompt)]);
    return response.text?.trim() ?? 'New Chat';
  }
}


