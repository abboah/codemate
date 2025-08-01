import 'dart:ui';
import 'package:codemate/components/build/project_confirmation_modal.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/services/project_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class DescribeModal extends ConsumerStatefulWidget {
  const DescribeModal({super.key});

  @override
  ConsumerState<DescribeModal> createState() => _DescribeModalState();
}

class _DescribeModalState extends ConsumerState<DescribeModal> {
  final TextEditingController _controller = TextEditingController();
  final ProjectAnalysisService _analysisService = ProjectAnalysisService();
  bool _isAnalyzing = false;

  Future<void> _analyzeDescription() async {
    if (_controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your project first.')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // 1. Start planning session
      final sessionId = await ref
          .read(projectsProvider)
          .startPlanningSession('describe', _controller.text);

      if (sessionId == null) {
        throw Exception("Failed to create a planning session.");
      }

      // 2. Analyze the description
      final analysis =
          await _analysisService.analyzeDescription(_controller.text);

      // 3. Update the session with the analysis
      await ref
          .read(projectsProvider)
          .updatePlanningSession(sessionId, analysis);

      if (!mounted) return;

      // 4. Show confirmation, which will pop with the new project ID.
      final newProjectId = await showDialog<String>(
        context: context, // This context is still valid.
        builder: (context) =>
            ProjectConfirmationModal(analysis: analysis, sessionId: sessionId),
      );

      if (!mounted) return;

      // 5. If we got a project ID, pop this modal and pass it back.
      if (newProjectId != null) {
        Navigator.of(context).pop(newProjectId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog.fullscreen(
        backgroundColor: Colors.black.withOpacity(0.5),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Describe Your Project'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            ],
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "What's your vision?",
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Describe the application you want to build. Be as detailed as you like.",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: 8,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            "e.g., 'A mobile app for tracking personal fitness goals with social sharing features...'",
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.4)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeDescription,
                      icon: _isAnalyzing
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(
                        _isAnalyzing ? 'ANALYZING...' : 'ANALYZE PROJECT',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
