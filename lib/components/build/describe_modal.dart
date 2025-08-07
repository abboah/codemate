import 'dart:ui';
import 'package:codemate/components/build/brainstorm_modal.dart';
import 'package:codemate/components/build/project_confirmation_modal.dart';
import 'package:codemate/services/project_analysis_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const Color seaBlue = Color(0xFF006994);

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
      // Directly analyze the description without creating a session
      final analysis =
          await _analysisService.analyzeDescription(_controller.text);

      if (!mounted) return;

      // Show confirmation, which will handle project creation and pop with the ID
      final newProjectId = await showDialog<String>(
        context: context,
        builder: (context) => ProjectConfirmationModal(analysis: analysis),
      );

      if (mounted && newProjectId != null) {
        // If we got a project ID, pop this modal and pass it back.
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
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Text(
                  "What's your vision?",
                  style: GoogleFonts.poppins(
                    fontSize: 28,
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
                const SizedBox(height: 24),
                _buildTextField(),
                const SizedBox(height: 24),
                _buildAnalyzeButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Describe Your Project',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildTextField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 10,
            autofocus: true,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  "e.g., 'A mobile app for tracking personal fitness goals with social sharing features...'",
              hintStyle: GoogleFonts.poppins(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalyzing ? null : _analyzeDescription,
        icon: _isAnalyzing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome_outlined, size: 18),
        label: Text(
          _isAnalyzing ? 'ANALYZING...' : 'ANALYZE & CREATE',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: seaBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
