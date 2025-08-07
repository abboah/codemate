import 'dart:ui';
import 'package:codemate/components/build/brainstorm_modal.dart';
import 'package:codemate/components/build/describe_modal.dart';
import 'package:codemate/screens/ide_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuildPageLanding extends StatelessWidget {
  const BuildPageLanding({super.key});

  void _showBrainstormModal(BuildContext context) async {
    final newProjectId = await showDialog<String>(
      context: context,
      builder: (context) => const BrainstormModal(),
    );
    if (newProjectId != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => IdePage(projectId: newProjectId),
        ),
      );
    }
  }

  void _showDescribeModal(BuildContext context) async {
    final newProjectId = await showDialog<String>(
      context: context,
      builder: (context) => const DescribeModal(),
    );
    if (newProjectId != null && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => IdePage(projectId: newProjectId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's build something new.",
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "How would you like to start?",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.lightbulb_outline,
                      title: 'Brainstorm',
                      description:
                          'Explore and refine your ideas through conversation.',
                      onTap: () => _showBrainstormModal(context),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _OptionCard(
                      icon: Icons.edit_note_outlined,
                      title: 'Describe',
                      description:
                          'Provide a detailed description if you have a clear vision.',
                      onTap: () => _showDescribeModal(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(24.0),
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_isHovered ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: Colors.white.withOpacity(_isHovered ? 0.3 : 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 32),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
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
