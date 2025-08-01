import 'dart:convert';
import 'package:codemate/components/build/brainstorm_modal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ProjectAnalysisService {
  final GenerativeModel _model;

  ProjectAnalysisService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash-lite',
          apiKey: dotenv.env['GEMINI_API_KEY']!,
        );

  String _extractJson(String text) {
    // Find the first '{' and the last '}' to extract the JSON object.
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    // Fallback if no JSON object is found.
    return '{}';
  }

  Future<ProjectAnalysis> analyzeDescription(String description) async {
    final prompt = """
    A developer provided this project description. Analyze it and infer the technical specifications:
    
    Description: "$description"
    
    Return ONLY a JSON object with this exact structure:
    {
      "projectTitle": "Inferred from description",
      "description": "Cleaned up version of the original description",
      "inferredFeatures": ["feature1", "feature2"],
      "recommendedStack": {
        "framework": "react|flutter|vue|etc",
        "backend": "suggested backend solution",
        "database": "suggested database",
        "reasoning": "Why this stack was chosen"
      },
      "technicalComplexity": "simple|moderate|complex",
      "estimatedTimeframe": "1-2 weeks|1 month|3+ months",
      "missingInformation": ["What needs clarification"],
      "confidence": 0.75
    }
    
    Focus on practical, modern tech stacks. If the description is vague, suggest the most common/beginner-friendly options.
    """;

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('Failed to get a response from the AI.');
    }

    final jsonString = _extractJson(response.text!);
    final jsonResponse = jsonDecode(jsonString);

    return ProjectAnalysis(
      projectTitle: jsonResponse['projectTitle'] ?? 'Untitled Project',
      description: jsonResponse['description'] ?? '',
      suggestedStack: [
        jsonResponse['recommendedStack']?['framework'] ?? 'not-set',
        jsonResponse['recommendedStack']?['backend'] ?? 'not-set',
        jsonResponse['recommendedStack']?['database'] ?? 'not-set',
      ],
      coreFeatures: List<String>.from(jsonResponse['inferredFeatures'] ?? []),
    );
  }
}
