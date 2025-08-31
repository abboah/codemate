import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:codemate/widgets/topic_interaction_modal.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/build_page.dart';

class EnrolledCoursePage extends ConsumerWidget {
  final Course course;
  final Enrollment enrollment;

  const EnrolledCoursePage({
    super.key,
    required this.course,
    required this.enrollment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(courseTopicsProvider(course.id));
    final topicStatusAsync = ref.watch(topicStatusProvider(enrollment.id));
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LearnPage()),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Subtle blue background with dark gradients
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.7, -0.8),
                  radius: 1.8,
                  colors: [
                    Color(0xFF0B1426),
                    Color(0xFF0A0F1C),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, 0.7),
                  radius: 1.5,
                  colors: [
                    Color(0xFF0D1B2A),
                    Color(0xFF0A1018),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Row(
              children: [
                PremiumSidebar(
                  items: [
                    PremiumSidebarItem(
                      icon: Icons.home,
                      label: 'Home',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.play_arrow_rounded,
                      label: 'Playground',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlaygroundPage()),
                      ),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.construction_rounded,
                      label: 'Build',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BuildPage()),
                      ),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.school_rounded,
                      label: 'Learn',
                      onTap: () {},
                      selected: true,
                    ),
                  ],
                  topPadding: 12,
                ),
                Expanded(
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Top bar with back (vertically centered)
                        Container(
                          height: kToolbarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const LearnPage()),
                                    (route) => false,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: screenWidth > 800
                              ? _buildDesktopLayout(context, ref, topicsAsync, topicStatusAsync)
                              : _buildMobileLayout(context, ref, topicsAsync, topicStatusAsync),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Topic>> topicsAsync,
    AsyncValue<List<UserTopicStatus>> topicStatusAsync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: _buildLeftColumn(context, ref, topicStatusAsync),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 32, 24, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _buildRightColumn(context, topicsAsync, topicStatusAsync),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Topic>> topicsAsync,
    AsyncValue<List<UserTopicStatus>> topicStatusAsync,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildLeftColumn(context, ref, topicStatusAsync),
          ),
          // Mobile: wrap right column in gradient panel and make scrollable vertically by parent
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildRightColumn(context, topicsAsync, topicStatusAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<UserTopicStatus>> topicStatusAsync,
  ) {
    return topicStatusAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BigShimmer(width: 200, height: 14),
              SizedBox(height: 12),
              BigShimmer(width: 160, height: 14),
              SizedBox(height: 12),
              BigShimmer(width: 180, height: 14),
            ],
          ),
        ),
      ),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (statuses) {
        final totalTopics = statuses.length;
        final completed = statuses.where((s) => s.status == 'completed').length;
        final inProgress = statuses.where((s) => s.status == 'in_progress').length;
        final progress = totalTopics > 0
            ? ((completed * 10 + inProgress * 5) / (totalTopics * 10)) * 100
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/course_images/${course.name.toLowerCase()}.png',
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.code, size: 60, color: Colors.white54),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              course.name,
              style: GoogleFonts.poppins(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              (course.description.isNotEmpty
                  ? course.description
                  : 'Master the fundamentals and advanced concepts'),
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Progress Section
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${progress.toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatItem('$completed', 'Completed'),
                      const SizedBox(width: 24),
                      _buildStatItem('$inProgress', 'In Progress'),
                      const SizedBox(width: 24),
                      _buildStatItem('${totalTopics - completed - inProgress}', 'Remaining'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Delete Button
            Container(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF121216),
                      title: Text(
                        'Delete Course?',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      content: Text(
                        'This action cannot be undone. All your progress will be lost.',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(color: Colors.white70),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (shouldDelete == true) {
                    await ref.read(deleteEnrollmentProvider(enrollment.id).future);
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LearnPage()),
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: Text(
                  'Delete Course',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(
    BuildContext context,
    AsyncValue<List<Topic>> topicsAsync,
    AsyncValue<List<UserTopicStatus>> topicStatusAsync,
  ) {
    return Container(
      margin: const EdgeInsets.all(24),
      child: topicsAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BigShimmer(width: 240, height: 14),
                SizedBox(height: 12),
                BigShimmer(width: 220, height: 14),
                SizedBox(height: 12),
                BigShimmer(width: 200, height: 14),
              ],
            ),
          ),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (topics) {
          return topicStatusAsync.when(
            loading: () => const Center(child: MiniWave(size: 28)),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (statuses) {
              final statusMap = {for (var s in statuses) s.topicId: s.status};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Course Content',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${topics.length} Topics',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: topics.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final topic = topics[index];
                      final status = statusMap[topic.id] ?? 'not_started';
                      return _TopicTile(
                        topic: topic,
                        status: status,
                        topicNumber: index + 1,
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.5),
                            builder: (context) => TopicInteractionModal(
                              topic: topic,
                              enrollment: enrollment,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final Topic topic;
  final String status;
  final int topicNumber;
  final VoidCallback onTap;

  const _TopicTile({
    required this.topic,
    required this.status,
    required this.topicNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isProject = topic.topicType == 'project';
    final isCompleted = status == 'completed';
    final isInProgress = status == 'in_progress';

    Color getBorderColor() {
      if (isCompleted) return Colors.green.withOpacity(0.4);
      if (isInProgress) return Colors.blue.withOpacity(0.4);
      return Colors.white.withOpacity(0.2);
    }

    Color getGradientStart() {
      if (isCompleted) return Colors.green.withOpacity(0.08);
      if (isInProgress) return Colors.blue.withOpacity(0.08);
      return Colors.white.withOpacity(0.04);
    }

    IconData getStatusIcon() {
      if (isCompleted) return Icons.check_circle;
      if (isInProgress) return Icons.play_circle_outline;
      return Icons.circle_outlined;
    }

    Color getIconColor() {
      if (isCompleted) return Colors.green;
      if (isInProgress) return Colors.blue;
      return Colors.white.withOpacity(0.6);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              getGradientStart(),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: getBorderColor(),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Topic Number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCompleted
                      ? [Colors.green, Colors.green.shade700]
                      : isInProgress
                          ? [Colors.blue, Colors.blue.shade700]
                          : [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$topicNumber',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Topic Type Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isProject
                      ? [Colors.amber.withOpacity(0.2), Colors.amber.withOpacity(0.1)]
                      : [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isProject
                      ? Colors.amber.withOpacity(0.3)
                      : AppColors.accent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                isProject ? Icons.assignment_turned_in_outlined : Icons.menu_book_outlined,
                color: isProject ? Colors.amber : AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Topic Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isProject
                              ? Colors.amber.withOpacity(0.15)
                              : AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isProject
                                ? Colors.amber.withOpacity(0.3)
                                : AppColors.accent.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isProject ? 'Project' : 'Lesson',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isProject ? Colors.amber : AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getIconColor().withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: getIconColor().withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getStatusIcon(),
                              color: getIconColor(),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompleted
                                  ? 'Completed'
                                  : isInProgress
                                      ? 'In Progress'
                                      : 'Not Started',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: getIconColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.4),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
