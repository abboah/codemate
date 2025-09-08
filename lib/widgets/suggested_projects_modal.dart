import 'dart:ui';
import 'package:codemate/providers/learn_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/widgets/fancy_loader.dart';

class SuggestedProjectsModal extends ConsumerStatefulWidget {
  final Topic topic;

  const SuggestedProjectsModal({super.key, required this.topic});

  @override
  ConsumerState<SuggestedProjectsModal> createState() =>
      _SuggestedProjectsModalState();
}

class _SuggestedProjectsModalState
    extends ConsumerState<SuggestedProjectsModal> {
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
    final projectsAsyncValue = ref.watch(
      suggestedProjectsProvider(widget.topic),
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
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
                                  const Color(0xFF7F00FF).withOpacity(0.3),
                                  const Color(0xFFE100FF).withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFFE100FF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Project Ideas',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hands-on projects for ${widget.topic.title}',
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
                        child: projectsAsyncValue.when(
                          data: (projects) {
                            if (projects.isEmpty) {
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
                                              0xFF7F00FF,
                                            ).withOpacity(0.3),
                                            const Color(
                                              0xFFE100FF,
                                            ).withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.build_outlined,
                                        color: Color(0xFFE100FF),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No project ideas yet',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Project suggestions will be available soon!',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Stack(
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
                                if (projects.length > 1) ...[
                                  Positioned(
                                    left: -10,
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
                                          Icons.arrow_back_ios,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _pageController.previousPage(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        style: IconButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -10,
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
                                          Icons.arrow_forward_ios,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _pageController.nextPage(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        style: IconButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
                                        'Could not load project ideas',
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

class _ProjectCard extends StatelessWidget {
  final SuggestedProject project;

  const _ProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  Icons.folder_copy_outlined,
                  color: Color(0xFF00A8FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  project.title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                project.description,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  project.stack
                      .map(
                        (tech) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF7F00FF).withOpacity(0.2),
                                const Color(0xFFE100FF).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE100FF).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tech,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE100FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${project.estimatedTimeHours}h',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Project saved! This feature will be fully implemented soon.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: const Color(0xFF00C851),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  'Add to Projects',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C851),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFF00E676);
                    }
                    return const Color(0xFF00C851);
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
