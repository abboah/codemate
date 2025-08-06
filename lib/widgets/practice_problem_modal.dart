import 'dart:ui';
import 'package:codemate/providers/learn_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class PracticeProblemModal extends ConsumerWidget {
  final Topic topic;

  const PracticeProblemModal({super.key, required this.topic});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problemsAsyncValue = ref.watch(practiceProblemsProvider(topic));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        child: Container(
          width: 800,
          height: 600,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Practice Problems: ${topic.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: problemsAsyncValue.when(
                        data: (problems) => ListView.builder(
                          itemCount: problems.length,
                          itemBuilder: (context, index) {
                            final problem = problems[index];
                            final description = problem.description;
                            final subtitleText = description.length > 100
                                ? '${description.substring(0, 100)}...'
                                : description;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: ListTile(
                                title: Text(problem.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(subtitleText, style: GoogleFonts.poppins(color: Colors.white70)),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PracticeProblemDetailView(problem: problem),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text(
                            'Oops! Could not load practice problems.\n${err.toString()}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.redAccent),
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
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
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
  ConsumerState<PracticeProblemDetailView> createState() => _PracticeProblemDetailViewState();
}

class _PracticeProblemDetailViewState extends ConsumerState<PracticeProblemDetailView> {
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
    final restOfSuggestion = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    final remarkStyles = {
      "Not quite": {'color': Colors.redAccent, 'text': "Not quite"},
      "Almost there": {'color': Colors.orangeAccent, 'text': "Almost there"},
      "Great": {'color': Colors.green, 'text': "Great"},
      "Excellent!": {'color': Colors.purpleAccent, 'text': "Excellent!"},
    };

    String? matchedKey;
    // More robust check for the remark, ignoring case and punctuation.
    for (var key in remarkStyles.keys) {
      if (firstLine.toLowerCase().contains(key.toLowerCase().replaceAll('!', ''))) {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (style['color'] as Color).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style['color'] as Color, width: 1),
        ),
        child: Text(
          style['text'] as String,
          style: GoogleFonts.poppins(
            color: style['color'] as Color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      contentToShow = restOfSuggestion;
      hasRemark = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        remarkPill,
        if (hasRemark) const SizedBox(height: 12),
        if (contentToShow.isNotEmpty)
          MarkdownBody(
            data: contentToShow,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              code: GoogleFonts.robotoMono(backgroundColor: Colors.black.withOpacity(0.5), color: Colors.white),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text(widget.problem.title, style: GoogleFonts.poppins()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Description & AI Suggestions
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    Text(widget.problem.description, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 30),
                    Text('AI Recommendations', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isGeneratingSuggestion
                          ? const Center(child: CircularProgressIndicator())
                          : _aiSuggestion != null
                              ? _buildAiSuggestionWidget(_aiSuggestion!)
                              : Text(
                                  'Run your code to get feedback from AI!',
                                  style: GoogleFonts.poppins(color: Colors.white38, fontStyle: FontStyle.italic),
                                ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Right Column: Code Editor
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      maxLines: null,
                      expands: true,
                      style: GoogleFonts.robotoMono(color: Colors.white),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: _runTests,
                        child: const Text('Run Tests'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _codeController.text = widget.problem.solution;
                          });
                        },
                        child: const Text('Show Solution'),
                      ),
                    ],
                  ),
                  if (_testResult.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(_testResult, style: GoogleFonts.poppins(color: _testResult.contains('passed') ? Colors.green : Colors.red, fontSize: 16)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}