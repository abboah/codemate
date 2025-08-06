import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/browse_courses_page.dart';
import 'package:codemate/screens/enrolled_course_page.dart';
import 'package:codemate/widgets/two_column_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class LearnPage extends ConsumerWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolledCoursesAsync = ref.watch(enrolledCoursesDetailsProvider);

    final rightColumnContent = enrolledCoursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (enrolledCourses) {
        if (enrolledCourses.isEmpty) {
          return const Center(
            child: Text(
              'You are not enrolled in any courses yet.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 20, right: 20),
          itemCount: enrolledCourses.length,
          itemBuilder: (context, index) {
            final details = enrolledCourses[index];
            return EnrolledCourseCard(details: details);
          },
        );
      },
    );

    return TwoColumnLayout(
      pageTitle: 'Learn',
      pageDescription: 'Explore guided learning paths and master new skills at your own pace.',
      buttonText: 'Browse Courses',
      onButtonPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BrowseCoursesPage()),
        );
      },
      rightColumnContent: rightColumnContent,
    );
  }
}

class EnrolledCourseCard extends ConsumerWidget {
  final EnrolledCourseDetails details;

  const EnrolledCourseCard({super.key, required this.details});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicStatusAsync = ref.watch(topicStatusProvider(details.enrollment.id));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnrolledCoursePage(
              course: details.course,
              enrollment: details.enrollment,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/course_images/${details.course.name.toLowerCase()}.png',
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 50,
                      width: 50,
                      color: Colors.white10,
                      child: const Icon(Icons.code, size: 30, color: Colors.blueAccent),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.course.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    topicStatusAsync.when(
                      loading: () => const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (err, stack) => const Text('Error', style: TextStyle(color: Colors.red)),
                      data: (statuses) {
                        final totalTopics = statuses.length;
                        final completed = statuses.where((s) => s.status == 'completed').length;
                        final progress = totalTopics > 0 ? completed / totalTopics : 0.0;
                        return Text(
                          '${(progress * 100).toStringAsFixed(0)}% Complete',
                          style: GoogleFonts.poppins(color: Colors.white70),
                        );
                      },
                    )
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    ref.read(deleteEnrollmentProvider(details.enrollment.id).future);
                  }
                },
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete Course'),
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
