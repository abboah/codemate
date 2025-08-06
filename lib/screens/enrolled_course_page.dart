import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:codemate/widgets/topic_interaction_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LearnPage()),
                (route) => false,
              );
            },
          ),
        ),
        body: screenWidth > 800
            ? _buildDesktopLayout(context, ref, topicsAsync, topicStatusAsync)
            : _buildMobileLayout(context, ref, topicsAsync, topicStatusAsync),
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
          child: _buildRightColumn(context, topicsAsync, topicStatusAsync),
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
          _buildRightColumn(context, topicsAsync, topicStatusAsync),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/course_images/${course.name.toLowerCase()}.png',
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 350,
                    color: Colors.white10,
                    child: const Icon(Icons.code, size: 60, color: Colors.blueAccent),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              course.name,
              style: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            // Progress Bar
            Text(
              '${progress.toStringAsFixed(0)}% Complete',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 40),
            // Delete Button
            TextButton.icon(
              onPressed: () async {
                await ref.read(deleteEnrollmentProvider(enrollment.id).future);
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LearnPage()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: Text(
                'Delete Course',
                style: GoogleFonts.poppins(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRightColumn(
    BuildContext context,
    AsyncValue<List<Topic>> topicsAsync,
    AsyncValue<List<UserTopicStatus>> topicStatusAsync,
  ) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (topics) {
          return topicStatusAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (statuses) {
              final statusMap = {for (var s in statuses) s.topicId: s.status};
              return ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  final status = statusMap[topic.id] ?? 'not_started';
                  return _TopicTile(
                    topic: topic,
                    status: status,
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
  final VoidCallback onTap;

  const _TopicTile({
    required this.topic,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isProject = topic.topicType == 'project';
    IconData statusIcon;
    Color statusColor;
    bool isCompleted = status == 'completed';

    switch (status) {
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.greenAccent;
        break;
      case 'in_progress':
        statusIcon = Icons.timelapse;
        statusColor = Colors.blueAccent;
        break;
      default:
        statusIcon = Icons.circle_outlined;
        statusColor = Colors.white54;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isCompleted ? 0.08 : 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(
              isProject ? Icons.assignment_turned_in_outlined : Icons.menu_book_outlined,
              color: isProject ? Colors.amber : Colors.blueAccent,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.white70 : Colors.white,
                      decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.description,
                    style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(statusIcon, color: statusColor),
          ],
        ),
      ),
    );
  }
}
