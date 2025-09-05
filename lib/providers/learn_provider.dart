import 'dart:convert';
import 'package:codemate/models/chat_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Models

class Course {
  final String id;
  final String name;
  final String description;
  final String courseType;
  final String? coverImageUrl;
  final int estimatedTimeHours;

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.courseType,
    this.coverImageUrl,
    required this.estimatedTimeHours,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      courseType: map['course_type'] ?? 'framework',
      coverImageUrl: map['cover_image_url'],
      estimatedTimeHours: map['estimated_time_hours'] ?? 0,
    );
  }
}

class Topic {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int topicOrder;
  final String topicType;
  final int estimatedTimeMinutes;

  Topic({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.topicOrder,
    required this.topicType,
    required this.estimatedTimeMinutes,
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'],
      courseId: map['course_id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      topicOrder: map['topic_order'] ?? 0,
      topicType: map['topic_type'] ?? 'regular',
      estimatedTimeMinutes: map['estimated_time_minutes'] ?? 0,
    );
  }
}

class Enrollment {
  final String id;
  final String userId;
  final String courseId;
  final String difficulty;
  final String learningStyle;

  Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.difficulty,
    required this.learningStyle,
  });

  factory Enrollment.fromMap(Map<String, dynamic> map) {
    return Enrollment(
      id: map['id'],
      userId: map['user_id'],
      courseId: map['course_id'],
      difficulty: map['difficulty'] ?? 'beginner',
      learningStyle: map['learning_style'] ?? 'visual',
    );
  }
}

class UserTopicStatus {
  final String id;
  final String enrollmentId;
  final String topicId;
  final String status;

  UserTopicStatus({
    required this.id,
    required this.enrollmentId,
    required this.topicId,
    required this.status,
  });

  factory UserTopicStatus.fromMap(Map<String, dynamic> map) {
    return UserTopicStatus(
      id: map['id'],
      enrollmentId: map['enrollment_id'],
      topicId: map['topic_id'],
      status: map['status'] ?? 'not_started',
    );
  }
}

class TopicNote {
  final String id;
  final String title;
  final String content;
  final int order;

  TopicNote({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
  });

  factory TopicNote.fromMap(Map<String, dynamic> map) {
    return TopicNote(
      id: map['id'],
      title: map['note_title'] ?? '',
      content: map['note_content'] ?? '',
      order: map['note_order'] ?? 0,
    );
  }
}

class QuizAttempt {
  final String id;
  final DateTime createdAt;

  QuizAttempt({required this.id, required this.createdAt});

  factory QuizAttempt.fromMap(Map<String, dynamic> map) {
    return QuizAttempt(
      id: map['id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class QuizQuestion {
  final String id;
  final String quizId;
  final int questionOrder;
  final String questionText;
  final Map<String, dynamic> options;
  final String correctOption;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.quizId,
    required this.questionOrder,
    required this.questionText,
    required this.options,
    required this.correctOption,
    required this.explanation,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['id'],
      quizId: map['quiz_id'],
      questionOrder: map['question_order'],
      questionText: map['question_text'],
      options: map['options'] is String ? jsonDecode(map['options']) : map['options'],
      correctOption: map['correct_option'],
      explanation: map['explanation'],
    );
  }
   Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quiz_id': quizId,
      'question_order': questionOrder,
      'question_text': questionText,
      'options': options,
      'correct_option': correctOption,
      'explanation': explanation,
    };
  }
}

class QuizAttemptWithQuestions {
  final QuizAttempt attempt;
  final List<QuizQuestion> questions;

  QuizAttemptWithQuestions({required this.attempt, required this.questions});
}


class EnrolledCourseDetails {
  final Course course;
  final Enrollment enrollment;

  EnrolledCourseDetails({required this.course, required this.enrollment});
}

class TopicFact {
  final String id;
  final String topicId;
  final String factText;

  TopicFact({
    required this.id,
    required this.topicId,
    required this.factText,
  });

  factory TopicFact.fromMap(Map<String, dynamic> map) {
    return TopicFact(
      id: map['id'],
      topicId: map['topic_id'],
      factText: map['fact_text'] ?? '',
    );
  }
}

class PracticeProblem {
  final String id;
  final String topicId;
  final String title;
  final String description;
  final String startingCode;
  final String solution;
  final List<Map<String, dynamic>> testCases;

  PracticeProblem({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.startingCode,
    required this.solution,
    required this.testCases,
  });

  factory PracticeProblem.fromMap(Map<String, dynamic> map) {
    return PracticeProblem(
      id: map['id'],
      topicId: map['topic_id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      startingCode: map['starting_code'] ?? '',
      solution: map['solution'] ?? '',
      testCases: List<Map<String, dynamic>>.from(map['test_cases'] ?? []),
    );
  }
}

class SuggestedProject {
  final String id;
  final String topicId;
  final String title;
  final String description;
  final List<String> stack;
  final int estimatedTimeHours;

  SuggestedProject({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.stack,
    required this.estimatedTimeHours,
  });

  factory SuggestedProject.fromMap(Map<String, dynamic> map) {
    return SuggestedProject(
      id: map['id'],
      topicId: map['topic_id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      stack: List<String>.from(map['stack'] ?? []),
      estimatedTimeHours: map['estimated_time_hours'] ?? 0,
    );
  }
}



// Providers

final supabase = Supabase.instance.client;
final gemini = GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: dotenv.env['GEMINI_API_KEY']!);

// Provider that creates a Gemini model instance for a given model name
final dynamicGeminiProvider = Provider.family<GenerativeModel, String>((ref, modelName) {
  return GenerativeModel(model: modelName, apiKey: dotenv.env['GEMINI_API_KEY']!);
});



// Provider to fetch all courses
final allCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final response = await supabase.from('courses').select();
  return (response as List).map((e) => Course.fromMap(e)).toList();
});

// Provider to fetch the current user's enrollments
final userEnrollmentsProvider = FutureProvider<List<Enrollment>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  final response = await supabase.from('enrollments').select().eq('user_id', user.id);
  return (response as List).map((e) => Enrollment.fromMap(e)).toList();
});

// Combined provider for enrolled courses with their details
final enrolledCoursesDetailsProvider = FutureProvider<List<EnrolledCourseDetails>>((ref) async {
  final allCourses = await ref.watch(allCoursesProvider.future);
  final userEnrollments = await ref.watch(userEnrollmentsProvider.future);

  if (userEnrollments.isEmpty) return [];

  final enrolledCourseIds = userEnrollments.map((e) => e.courseId).toSet();
  final enrollmentsMap = { for (var e in userEnrollments) e.courseId : e };

  return allCourses
      .where((course) => enrolledCourseIds.contains(course.id))
      .map((course) => EnrolledCourseDetails(
            course: course,
            enrollment: enrollmentsMap[course.id]!,
          ))
      .toList();
});

// Provider to fetch topics for a specific course
final courseTopicsProvider = FutureProvider.family<List<Topic>, String>((ref, courseId) async {
  final response = await supabase.from('topics').select().eq('course_id', courseId).order('topic_order', ascending: true);
  return (response as List).map((e) => Topic.fromMap(e)).toList();
});

// Provider to fetch topic statuses for a given enrollment
final topicStatusProvider = FutureProvider.family<List<UserTopicStatus>, String>((ref, enrollmentId) async {
  final response = await supabase.from('user_topic_status').select().eq('enrollment_id', enrollmentId);
  return (response as List).map((e) => UserTopicStatus.fromMap(e)).toList();
});

// Provider to enroll a user in a course and get the new enrollment record
final enrollInCourseProvider = FutureProvider.family<Enrollment, Map<String, dynamic>>((ref, enrollmentData) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw 'User not authenticated';

  final response = await supabase.from('enrollments').insert({
    'user_id': user.id,
    'course_id': enrollmentData['course_id'],
    'difficulty': enrollmentData['difficulty'],
    'learning_style': enrollmentData['learning_style'],
  }).select().single();

  // Invalidate providers to refetch data
  ref.invalidate(userEnrollmentsProvider);
  ref.invalidate(enrolledCoursesDetailsProvider);
  return Enrollment.fromMap(response);
});

// Provider to delete an enrollment
final deleteEnrollmentProvider = FutureProvider.family<void, String>((ref, enrollmentId) async {
  await supabase.from('enrollments').delete().eq('id', enrollmentId);
  ref.invalidate(userEnrollmentsProvider);
  ref.invalidate(enrolledCoursesDetailsProvider);
});

// Provider to fetch existing notes for a topic.
final topicNotesProvider = FutureProvider.autoDispose.family<List<TopicNote>, Map<String, String>>((ref, ids) async {
  final enrollmentId = ids['enrollmentId']!;
  final topicId = ids['topicId']!;
  
  final response = await supabase
      .from('topic_notes')
      .select()
      .eq('enrollment_id', enrollmentId)
      .eq('topic_id', topicId)
      .order('note_order', ascending: true);

  return (response as List).map((e) => TopicNote.fromMap(e)).toList();
});

// Provider to create new notes for a topic. Now returns the created notes.
final createNotesProvider = FutureProvider.autoDispose.family<List<TopicNote>, Map<String, dynamic>>((ref, data) async {
  final Topic topic = data['topic'];
  final Enrollment enrollment = data['enrollment'];

  print('[createNotesProvider] Starting note generation for topic: ${topic.title}');

  final prompt = """
    You are an expert educator and content creator. Your task is to generate a comprehensive, three-part lesson on the topic "${topic.title}" for a student with a '${enrollment.difficulty}' skill level and a '${enrollment.learningStyle}' learning style.

    The topic description is: "${topic.description}".

    **Formatting Rules (Crucial):**
    - The entire response MUST be in Markdown format.
    - DO NOT wrap the entire response in a single code block (e.g., starting with ```).
    - Use LaTeX for any mathematical equations, enclosed in single dollar signs for inline (\$) or double for blocks (\$\$).
    - Structure your response into exactly three sections, separated by a unique delimiter: `<!--- NOTE_SEPARATOR --->`.
    - Each section must have a title. The titles MUST be: "Getting Started", "Putting It to Work", and "Mastery & Beyond".

    **Content Guidelines:**
    - **Getting Started:** Introduce the core concepts. Be welcoming and provide foundational knowledge.
    - **Putting It to Work:** Focus on practical application. Provide code examples, case studies, or step-by-step instructions.
    - **Mastery & Beyond:** Explore advanced concepts, edge cases, and professional best practices. Challenge the learner to think further.

    Generate the lesson now.
  """;

  final response = await gemini.generateContent([Content.text(prompt)]);
  final content = response.text;

  if (content == null) {
    throw Exception('Failed to generate notes from AI.');
  }

  final parts = content.split('<!--- NOTE_SEPARATOR --->');
  if (parts.length != 3) {
    throw Exception('AI response was not formatted into three parts correctly.');
  }

  final notesToInsert = [
    {
      'enrollment_id': enrollment.id,
      'topic_id': topic.id,
      'note_title': 'Getting Started',
      'note_content': parts[0].trim(),
      'note_order': 1,
    },
    {
      'enrollment_id': enrollment.id,
      'topic_id': topic.id,
      'note_title': 'Putting It to Work',
      'note_content': parts[1].trim(),
      'note_order': 2,
    },
    {
      'enrollment_id': enrollment.id,
      'topic_id': topic.id,
      'note_title': 'Mastery & Beyond',
      'note_content': parts[2].trim(),
      'note_order': 3,
    },
  ];

  final insertedData = await supabase.from('topic_notes').insert(notesToInsert).select();
  print('[createNotesProvider] Notes successfully inserted into database.');
  return (insertedData as List).map((e) => TopicNote.fromMap(e)).toList();
});




// Provider to fetch all quiz attempts for a topic, including all their questions
final quizAttemptsWithQuestionsProvider = FutureProvider.autoDispose.family<List<QuizAttemptWithQuestions>, Map<String, String>>((ref, ids) async {
  final enrollmentId = ids['enrollmentId']!;
  final topicId = ids['topicId']!;
  print('[QuizProvider] Fetching attempts for enrollment: $enrollmentId, topic: $topicId');

  // 1. Fetch all quiz attempts (topic_quizzes)
  final attemptsResponse = await supabase
      .from('topic_quizzes')
      .select('id, created_at')
      .eq('enrollment_id', enrollmentId)
      .eq('topic_id', topicId)
      .order('created_at', ascending: false);

  final attempts = (attemptsResponse as List).map((e) => QuizAttempt.fromMap(e)).toList();
  print('[QuizProvider] Found ${attempts.length} attempts.');

  if (attempts.isEmpty) {
    return [];
  }

  // 2. Get all quiz IDs
  final quizIds = attempts.map((a) => a.id).toList();
  print('[QuizProvider] Fetching questions for quiz IDs: $quizIds');

  // 3. Fetch all questions for those quiz IDs in a single query
  final questionsResponse = await supabase
      .from('quiz_questions')
      .select()
      .filter('quiz_id', 'in', quizIds)
      .order('question_order', ascending: true);

  final allQuestions = (questionsResponse as List).map((q) => QuizQuestion.fromMap(q)).toList();
  print('[QuizProvider] Found ${allQuestions.length} total questions.');

  // 4. Group questions by quiz_id
  final questionsByQuizId = <String, List<QuizQuestion>>{};
  for (var question in allQuestions) {
    questionsByQuizId.putIfAbsent(question.quizId, () => []).add(question);
  }

  // 5. Combine attempts with their questions
  final result = attempts.map((attempt) {
    final questionsForAttempt = questionsByQuizId[attempt.id] ?? [];
    print('[QuizProvider] Attempt ${attempt.id} has ${questionsForAttempt.length} questions.');
    return QuizAttemptWithQuestions(
      attempt: attempt,
      questions: questionsForAttempt,
    );
  }).toList();
  
  print('[QuizProvider] Returning ${result.length} attempts with their questions.');
  return result;
});


// Provider to create a new quiz
final createQuizProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, data) async {
  final Topic topic = data['topic'];
  final Enrollment enrollment = data['enrollment'];

  // Step 1: Fetch or create notes directly.
  final ids = {'enrollmentId': enrollment.id, 'topicId': topic.id};
  var notes = await ref.read(topicNotesProvider(ids).future);

  if (notes.isEmpty) {
    notes = await ref.read(createNotesProvider(data).future);
  }
  
  if (notes.isEmpty) {
    throw Exception('Cannot create quiz without notes.');
  }

  final notesContent = notes.map((n) => n.content).join('\n\n---\n\n');

  
  final prompt = """
    Based *only* on the following text, create a 10-question multiple-choice quiz.
    The questions should test the key concepts from the text.

    **Formatting Rules (Crucial):**
    - Your entire response MUST be a single, valid JSON array.
    - Each object in the array represents a question.
    - Each question object must have these exact keys: "question_text", "options", "correct_option", "explanation".
    - "options" must be a JSON object where keys are "A", "B", "C", "D" and values are the answer strings.
    - "correct_option" must be the key of the correct answer (e.g., "A").
    - "explanation" must be a brief explanation of why the answer is correct.
    - Do not include any text or markdown formatting outside of the JSON array.

    **Text to analyze:**
    ---
    $notesContent
    ---
  """;

  final response = await gemini.generateContent([Content.text(prompt)]);
  final jsonString = response.text!.replaceAll("```json", "").replaceAll("```", "").trim();
  final List<dynamic> questionsJson = jsonDecode(jsonString);

  final newQuiz = await supabase
      .from('topic_quizzes')
      .insert({'enrollment_id': enrollment.id, 'topic_id': topic.id})
      .select()
      .single();

  final questionsToInsert = questionsJson.asMap().entries.map((entry) {
    int idx = entry.key;
    Map<String, dynamic> q = entry.value;
    return {
      'quiz_id': newQuiz['id'],
      'question_order': idx + 1,
      'question_text': q['question_text'],
      'options': q['options'],
      'correct_option': q['correct_option'],
      'explanation': q['explanation'],
    };
  }).toList();

  await supabase.from('quiz_questions').insert(questionsToInsert);

  // Invalidate the attempts provider so the lobby refreshes
  ref.invalidate(quizAttemptsWithQuestionsProvider({'enrollmentId': enrollment.id, 'topicId': topic.id}));

  return (await supabase.from('quiz_questions').select().eq('quiz_id', newQuiz['id']))
      .map((q) => q as Map<String, dynamic>)
      .toList();
});

// Provider to fetch all chat sessions for a topic
final topicChatsProvider = FutureProvider.autoDispose.family<List<TopicChat>, Map<String, String>>((ref, ids) async {
  final enrollmentId = ids['enrollmentId']!;
  final topicId = ids['topicId']!;

  final response = await supabase
      .from('topic_chats')
      .select()
      .eq('enrollment_id', enrollmentId)
      .eq('topic_id', topicId)
      .order('created_at', ascending: false);
  
  return (response as List).map((e) => TopicChat.fromMap(e)).toList();
});

// Provider to fetch all messages for a specific chat session
final chatMessagesProvider = FutureProvider.autoDispose.family<List<ChatMessage>, String>((ref, chatId) async {
  final response = await supabase
      .from('chat_messages')
      .select()
      .eq('chat_id', chatId)
      .order('sent_at', ascending: true);

  return (response as List).map((e) => ChatMessage.fromMap(e)).toList();
});

// Provider to send a message in an existing chat
final sendMessageProvider = Provider.autoDispose((ref) {
  return (Map<String, dynamic> data) async {
    final String chatId = data['chatId'];
    final String content = data['content'];
    final String sender = data['sender'];
    
    await supabase.from('chat_messages').insert({
      'chat_id': chatId,
      'sender': sender,
      'content': content,
    });
  };
});

// Provider to create a new chat session
final createTopicChatProvider = FutureProvider.autoDispose.family<TopicChat, Map<String, dynamic>>((ref, data) async {
  final Enrollment enrollment = data['enrollment'];
  final Topic topic = data['topic'];
  final String firstMessage = data['message'];
  final String aiResponse = data['aiResponse'];

  // Generate a title for the chat
  final titlePrompt = """
    Based on the following conversation, create a very short, concise title (5 words or less).

    USER: "$firstMessage"
    AI: "$aiResponse"

    TITLE:
  """;
  final titleResponse = await gemini.generateContent([Content.text(titlePrompt)]);
  final chatTitle = titleResponse.text?.trim() ?? 'New Chat';

  // Create the new chat session in the database
  final newChat = await supabase.from('topic_chats').insert({
    'enrollment_id': enrollment.id,
    'topic_id': topic.id,
    'title': chatTitle,
  }).select().single();

  final chatId = newChat['id'];

  // Save the first two messages
  await supabase.from('chat_messages').insert([
    {'chat_id': chatId, 'sender': 'user', 'content': firstMessage},
    {'chat_id': chatId, 'sender': 'ai', 'content': aiResponse},
  ]);

  // Invalidate the chats provider to refetch the list
  ref.invalidate(topicChatsProvider({'enrollmentId': enrollment.id, 'topicId': topic.id}));

  return TopicChat.fromMap(newChat);
});

// Provider to fetch or generate fun facts for a topic
final topicFactsProvider = FutureProvider.autoDispose.family<List<TopicFact>, Topic>((ref, topic) async {
  // 1. Check if facts already exist in the database
  final existingFactsResponse = await supabase
      .from('topic_facts')
      .select()
      .eq('topic_id', topic.id);

  if (existingFactsResponse.isNotEmpty) {
    print('[topicFactsProvider] Found existing facts for topic: ${topic.title}');
    return (existingFactsResponse as List).map((e) => TopicFact.fromMap(e)).toList();
  }

  // 2. If not, generate new facts using the AI
  print('[topicFactsProvider] No existing facts. Generating new ones for topic: ${topic.title}');
  final prompt = """
    You are a master of trivia and fun facts.
    Generate exactly 3 interesting and fun facts about the topic: "${topic.title}".

    **Formatting Rules (Crucial):**
    - Each fact must be a single, complete sentence.
    - Separate each of the 3 facts with a unique delimiter: `<!--- FACT_SEPARATOR --->`
    - Do not use any other formatting, titles, or numbers. Just the facts separated by the delimiter.

    Generate the facts now.
  """;

  final response = await gemini.generateContent([Content.text(prompt)]);
  final content = response.text;

  if (content == null || content.isEmpty) {
    throw Exception('Failed to generate fun facts from AI.');
  }

  final parts = content.split('<!--- FACT_SEPARATOR --->');
  if (parts.length != 3) {
    throw Exception('AI response for facts was not formatted into three parts correctly.');
  }

  // 3. Insert the new facts into the database
  final factsToInsert = parts.map((fact) => {
    'topic_id': topic.id,
    'fact_text': fact.trim(),
  }).toList();

  final insertedData = await supabase.from('topic_facts').insert(factsToInsert).select();
  print('[topicFactsProvider] New facts successfully inserted into the database.');
  
  // 4. Return the newly created facts
  return (insertedData as List).map((e) => TopicFact.fromMap(e)).toList();
});

// Provider to fetch or generate practice problems for a topic
final practiceProblemsProvider = FutureProvider.autoDispose.family<List<PracticeProblem>, Topic>((ref, topic) async {
  // 1. Check if problems already exist
  final existingProblemsResponse = await supabase
      .from('topic_practice_problems')
      .select()
      .eq('topic_id', topic.id);

  if (existingProblemsResponse.isNotEmpty) {
    print('[PracticeProvider] Found existing problems for topic: ${topic.title}');
    return (existingProblemsResponse as List).map((e) => PracticeProblem.fromMap(e)).toList();
  }

  // 2. If not, generate new problems
  print('[PracticeProvider] No existing problems. Generating new ones for topic: ${topic.title}');
  final prompt = """
    You are a JSON generation expert. Your sole task is to create content for a programming practice app.
    Generate exactly 3 distinct practice problems for the topic: "${topic.title}".

    **CRITICAL FORMATTING RULES:**
    - Your entire response MUST be ONLY a single, valid JSON array.
    - DO NOT output the word "json" or use markdown backticks (```).
    - DO NOT include ANY text, explanation, or formatting outside of the main JSON array. Your response must start with `[` and end with `]`.
    - Each object in the array represents a practice problem.
    - Each problem object MUST have these exact keys: "title", "description", "starting_code", "solution", "test_cases".
    - "test_cases" MUST be a JSON array of objects, where each object has an "input" and an "expected" key. Provide at least 3 test cases.
    - Ensure the code is relevant to the topic. For example, if the topic is "Flutter Widgets", the code should be Dart/Flutter code.

    Generate the JSON array now.
  """;

  final response = await gemini.generateContent([Content.text(prompt)]);
  final textResponse = response.text;

  if (textResponse == null || textResponse.isEmpty) {
    throw Exception('Failed to generate practice problems: AI returned an empty response.');
  }

  String jsonString;
  try {
    // Aggressively find the start and end of the JSON array
    final startIndex = textResponse.indexOf('[');
    final endIndex = textResponse.lastIndexOf(']');

    if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
      throw FormatException('Could not find a valid JSON array in the AI response. Raw response: $textResponse');
    }

    jsonString = textResponse.substring(startIndex, endIndex + 1);
    
    final List<dynamic> problemsJson = jsonDecode(jsonString);

    // 3. Insert new problems into the database
    final problemsToInsert = problemsJson.map((p) {
      // Basic validation to ensure keys exist
      if (p['title'] == null || p['description'] == null || p['starting_code'] == null || p['solution'] == null || p['test_cases'] == null) {
        throw FormatException('AI-generated JSON is missing required keys.');
      }
      return {
        'topic_id': topic.id,
        'title': p['title'],
        'description': p['description'],
        'starting_code': p['starting_code'],
        'solution': p['solution'],
        'test_cases': p['test_cases'],
      };
    }).toList();

    final insertedData = await supabase.from('topic_practice_problems').insert(problemsToInsert).select();
    print('[PracticeProvider] New problems successfully inserted into the database.');

    // 4. Return the newly created problems
    return (insertedData as List).map((e) => PracticeProblem.fromMap(e)).toList();

  } catch (e) {
    print('Error parsing AI response for practice problems. Error: $e');
    // Re-throw with more context for easier debugging
    throw FormatException('Failed to parse practice problems JSON. Cleaned string was: $textResponse');
  }
});

// Provider to fetch or generate suggested projects for a topic
final suggestedProjectsProvider = FutureProvider.autoDispose.family<List<SuggestedProject>, Topic>((ref, topic) async {
  // 1. Check if projects already exist
  final existingProjectsResponse = await supabase
      .from('suggested_projects')
      .select()
      .eq('topic_id', topic.id);

  if (existingProjectsResponse.isNotEmpty) {
    print('[ProjectsProvider] Found existing projects for topic: ${topic.title}');
    return (existingProjectsResponse as List).map((e) => SuggestedProject.fromMap(e)).toList();
  }

  // 2. If not, generate new projects
  print('[ProjectsProvider] No existing projects. Generating new ones for topic: ${topic.title}');
  final prompt = """
    You are a JSON generation expert for a programming education app.
    Generate exactly 2 distinct project ideas for the topic: "${topic.title}".

    **CRITICAL FORMATTING RULES:**
    - Your entire response MUST be ONLY a single, valid JSON array.
    - DO NOT output the word "json" or use markdown backticks (```).
    - Your response must start with `[` and end with `]`.
    - Each object in the array represents a suggested project.
    - Each project object MUST have these exact keys: "title", "description", "stack", "estimated_time_hours".
    - "stack" MUST be a JSON array of strings.
    - "estimated_time_hours" MUST be an integer.
    - Ensure there is a comma separating the JSON objects in the array.

    **EXAMPLE OUTPUT:**
    [
      {
        "title": "Project 1 Title",
        "description": "Description for project 1.",
        "stack": ["Tech1", "Tech2"],
        "estimated_time_hours": 5
      },
      {
        "title": "Project 2 Title",
        "description": "Description for project 2.",
        "stack": ["Tech3", "Tech4"],
        "estimated_time_hours": 8
      }
    ]

    Generate the JSON array now.
  """;

  final response = await gemini.generateContent([Content.text(prompt)]);
  final textResponse = response.text;

  if (textResponse == null || textResponse.isEmpty) {
    throw Exception('Failed to generate suggested projects: AI returned an empty response.');
  }

  try {
    // Clean the response string
    String cleanedJson = textResponse
        .replaceAll("```json", "")
        .replaceAll("```", "")
        .trim();

    // Find the start and end of the JSON array
    final startIndex = cleanedJson.indexOf('[');
    final endIndex = cleanedJson.lastIndexOf(']');

    if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
      throw FormatException('Could not find a valid JSON array in the AI response.');
    }

    String jsonString = cleanedJson.substring(startIndex, endIndex + 1);

    // Make parsing more robust by fixing common AI mistakes
    // Fixes missing commas between objects: "} {", "} \n {", etc.
    jsonString = jsonString.replaceAll(RegExp(r'}\s*{'), '},{');

    final List<dynamic> projectsJson = jsonDecode(jsonString);

    // 3. Insert new projects into the database
    final projectsToInsert = projectsJson.map((p) {
      if (p['title'] == null || p['description'] == null || p['stack'] == null || p['estimated_time_hours'] == null) {
        throw FormatException('AI-generated JSON is missing required keys.');
      }
      return {
        'topic_id': topic.id,
        'title': p['title'],
        'description': p['description'],
        'stack': p['stack'],
        'estimated_time_hours': p['estimated_time_hours'],
      };
    }).toList();

    final insertedData = await supabase.from('suggested_projects').insert(projectsToInsert).select();
    print('[ProjectsProvider] New projects successfully inserted into the database.');

    // 4. Return the newly created projects
    return (insertedData as List).map((e) => SuggestedProject.fromMap(e)).toList();

  } catch (e) {
    print('Error parsing AI response for suggested projects. Error: $e');
    throw FormatException('Failed to parse suggested projects JSON. Raw response was: $textResponse');
  }
});