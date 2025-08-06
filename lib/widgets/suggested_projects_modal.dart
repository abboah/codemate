import 'dart:ui';
import 'package:codemate/providers/learn_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class SuggestedProjectsModal extends ConsumerStatefulWidget {
  final Topic topic;

  const SuggestedProjectsModal({super.key, required this.topic});

  @override
  ConsumerState<SuggestedProjectsModal> createState() => _SuggestedProjectsModalState();
}

class _SuggestedProjectsModalState extends ConsumerState<SuggestedProjectsModal> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(suggestedProjectsProvider(widget.topic));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        child: Container(
          width: 600,
          height: 500, // Increased height to accommodate new elements
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // 'Project Ideas for ${widget.topic.title}',
                      'Here\'s Some Projects You Can Try',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: projectsAsyncValue.when(
                        data: (projects) => Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: projects.length,
                              itemBuilder: (context, index) {
                                final project = projects[index];
                                return _ProjectCard(project: project);
                              },
                            ),
                            Positioned(
                              left: -10,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              right: -10,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54),
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                          child: Text(
                            'Oops! Could not load project ideas.\n${err.toString()}',
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

class _ProjectCard extends StatelessWidget {
  final SuggestedProject project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                project.description,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: project.stack.map((tech) => Chip(
              label: Text(tech),
              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.3),
              labelStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
              side: BorderSide(color: Colors.deepPurpleAccent),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${project.estimatedTimeHours} hours',
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement "Add to Projects" functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('This feature will be implemented soon!')), 
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add to Projects'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
