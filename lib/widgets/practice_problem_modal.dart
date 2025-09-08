import 'dart:ui';
import 'package:codemate/providers/learn_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:codemate/widgets/fancy_loader.dart';

class PracticeProblemModal extends ConsumerWidget {
  final Topic topic;

  const PracticeProblemModal({super.key, required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problemsAsyncValue = ref.watch(practiceProblemsProvider(topic));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0A0D).withOpacity(0.95),
                  const Color(0xFF121216).withOpacity(0.92),
                  const Color(0xFF1A1A20).withOpacity(0.90),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00A8FF).withOpacity(0.3),
                                  const Color(0xFF0078FF).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.code,
                              color: Color(0xFF00A8FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Practice Problems',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topic.title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: problemsAsyncValue.when(
                          data: (problems) {
                            if (problems.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF00A8FF,
                                            ).withOpacity(0.3),
                                            const Color(
                                              0xFF0078FF,
                                            ).withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined,
                                        color: Color(0xFF00A8FF),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No practice problems yet',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Practice problems will be available soon!',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: problems.length,
                              itemBuilder: (context, index) {
                                final problem = problems[index];
                                final description = problem.description;
                                final subtitleText =
                                    description.length > 100
                                        ? '${description.substring(0, 100)}...'
                                        : description;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.08),
                                        Colors.white.withOpacity(0.04),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    PracticeProblemDetailView(
                                                      problem: problem,
                                                    ),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(
                                                      0xFF7F00FF,
                                                    ).withOpacity(0.3),
                                                    const Color(
                                                      0xFFE100FF,
                                                    ).withOpacity(0.3),
                                                  ],
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: GoogleFonts.poppins(
                                                    color: const Color(
                                                      0xFFE100FF,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    problem.title,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    subtitleText,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white
                                                          .withOpacity(0.7),
                                                      fontSize: 14,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(
                                                  0.1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const ModalSkeleton(),
                          error:
                              (err, stack) => Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.redAccent,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Could not load practice problems',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.redAccent,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Please try again later',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
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
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PracticeProblemDetailView extends ConsumerStatefulWidget {
  final PracticeProblem problem;

  const PracticeProblemDetailView({super.key, required this.problem});

  @override
  ConsumerState<PracticeProblemDetailView> createState() =>
      _PracticeProblemDetailViewState();
}

class _PracticeProblemDetailViewState
    extends ConsumerState<PracticeProblemDetailView> {
  late TextEditingController _codeController;
  String _testResult = '';
  String? _aiSuggestion;
  bool _isGeneratingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.problem.startingCode);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateAiSuggestion() async {
    setState(() {
      _isGeneratingSuggestion = true;
      _aiSuggestion = null;
    });

    final gemini = ref.read(dynamicGeminiProvider('gemini-1.5-flash-latest'));
    final prompt = """
      You are a code review expert. A user has submitted a solution to a coding problem. 
      Your task is to compare their code to the correct solution and provide constructive feedback.

      **Problem Description:**
      ${widget.problem.description}

      **User's Code:**
      ```
      ${_codeController.text}
      ```

      **Correct Solution:**
      ```
      ${widget.problem.solution}
      ```

      **Instructions:**
      1. **Start your response with an evaluation remark on its own line.** Choose one of the following based on the user's submission: "Not quite", "Almost there", "Great", or "Excellent!".
      2. Analyze the user's code for correctness, efficiency, and style.
      3. If the user's code is incorrect, explain the error and guide them toward the correct solution.
      4. If the user's code is correct, suggest alternative approaches, optimizations, or ways to make the code more idiomatic or readable.
      5. Keep your feedback concise, positive, and encouraging. Format the rest of your response using Markdown.
    """;

    try {
      final response = await gemini.generateContent([Content.text(prompt)]);
      setState(() {
        _aiSuggestion = response.text;
      });
    } catch (e) {
      setState(() {
        _aiSuggestion = "Sorry, I couldn't generate a suggestion at this time.";
      });
    } finally {
      setState(() {
        _isGeneratingSuggestion = false;
      });
    }
  }

  void _runTests() {
    // This is a simplified test runner. A real implementation would need a more robust solution.
    if (_codeController.text == widget.problem.solution) {
      setState(() {
        _testResult = 'All tests passed!';
      });
    } else {
      setState(() {
        _testResult = 'Some tests failed. Try again!';
      });
    }
    // Always generate a suggestion after running tests
    _generateAiSuggestion();
  }

  Widget _buildAiSuggestionWidget(String suggestion) {
    final lines = suggestion.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
    final restOfSuggestion =
        lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    final remarkStyles = {
      "Not quite": {
        'color': Colors.redAccent,
        'text': "Not quite",
        'icon': Icons.close,
      },
      "Almost there": {
        'color': Colors.orangeAccent,
        'text': "Almost there",
        'icon': Icons.trending_up,
      },
      "Great": {
        'color': const Color(0xFF00C851),
        'text': "Great",
        'icon': Icons.thumb_up,
      },
      "Excellent!": {
        'color': const Color(0xFFE100FF),
        'text': "Excellent!",
        'icon': Icons.emoji_events,
      },
    };

    String? matchedKey;
    // More robust check for the remark, ignoring case and punctuation.
    for (var key in remarkStyles.keys) {
      if (firstLine.toLowerCase().contains(
        key.toLowerCase().replaceAll('!', ''),
      )) {
        matchedKey = key;
        break;
      }
    }

    Widget remarkPill = const SizedBox.shrink();
    String contentToShow = suggestion;
    bool hasRemark = false;

    if (matchedKey != null) {
      final style = remarkStyles[matchedKey]!;
      remarkPill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (style['color'] as Color).withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: style['color'] as Color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              style['icon'] as IconData,
              color: style['color'] as Color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              style['text'] as String,
              style: GoogleFonts.poppins(
                color: style['color'] as Color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
      contentToShow = restOfSuggestion;
      hasRemark = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRemark) ...[remarkPill, const SizedBox(height: 16)],
        if (contentToShow.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: MarkdownBody(
              data: contentToShow,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(
                p: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
                code: GoogleFonts.robotoMono(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: const Color(0xFF00A8FF),
                  fontSize: 13,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                h1: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h2: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                h3: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                listBullet: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        title: Text(
          widget.problem.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF121216),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF121216), const Color(0xFF0A0A0D)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Description & AI Suggestions
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00A8FF).withOpacity(0.3),
                                      const Color(0xFF0078FF).withOpacity(0.3),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: Color(0xFF00A8FF),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Problem Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              widget.problem.description,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7F00FF).withOpacity(0.3),
                                      const Color(0xFFE100FF).withOpacity(0.3),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.smart_toy_outlined,
                                  color: Color(0xFFE100FF),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'AI Recommendations',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child:
                                _isGeneratingSuggestion
                                    ? const ModalSkeleton(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    )
                                    : _aiSuggestion != null
                                    ? _buildAiSuggestionWidget(_aiSuggestion!)
                                    : Column(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(
                                                  0xFFE100FF,
                                                ).withOpacity(0.2),
                                                const Color(
                                                  0xFF7F00FF,
                                                ).withOpacity(0.2),
                                              ],
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.psychology_outlined,
                                            color: Color(0xFFE100FF),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Run your code to get personalized feedback from Robin!',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontStyle: FontStyle.italic,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Code Editor
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00C851).withOpacity(0.3),
                                    const Color(0xFF007E33).withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.code,
                                color: Color(0xFF00C851),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Code Editor',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: _codeController,
                              maxLines: null,
                              expands: true,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.transparent,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(20),
                                hintText: 'Write your solution here...',
                                hintStyle: GoogleFonts.robotoMono(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: _runTests,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C851),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ).copyWith(
                                backgroundColor:
                                    MaterialStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        MaterialState.hovered,
                                      )) {
                                        return const Color(0xFF00E676);
                                      }
                                      return const Color(0xFF00C851);
                                    }),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Run Tests',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _codeController.text =
                                      widget.problem.solution;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ).copyWith(
                                backgroundColor:
                                    MaterialStateProperty.resolveWith((states) {
                                      if (states.contains(
                                        MaterialState.hovered,
                                      )) {
                                        return Colors.white.withOpacity(0.1);
                                      }
                                      return Colors.transparent;
                                    }),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Show Solution',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_testResult.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  _testResult.contains('passed')
                                      ? const Color(0xFF00C851).withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _testResult.contains('passed')
                                        ? const Color(
                                          0xFF00C851,
                                        ).withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _testResult.contains('passed')
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color:
                                      _testResult.contains('passed')
                                          ? const Color(0xFF00C851)
                                          : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _testResult,
                                  style: GoogleFonts.poppins(
                                    color:
                                        _testResult.contains('passed')
                                            ? const Color(0xFF00C851)
                                            : Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
