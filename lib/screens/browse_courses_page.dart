import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/course_details_page.dart';
import 'package:codemate/widgets/pill_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class BrowseCoursesPage extends ConsumerStatefulWidget {
  const BrowseCoursesPage({super.key});

  @override
  ConsumerState<BrowseCoursesPage> createState() => _BrowseCoursesPageState();
}

class _BrowseCoursesPageState extends ConsumerState<BrowseCoursesPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(allCoursesProvider);
    final enrollmentsAsync = ref.watch(userEnrollmentsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'What will you learn?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Center(
              child: SizedBox(
                width: 300,
                child: PillToggleSwitch(
                  selectedIndex: _selectedIndex,
                  labels: const ['Languages', 'Frameworks'],
                  onToggle: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: coursesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (courses) {
                return enrollmentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (enrollments) {
                    final enrolledCourseIds = enrollments.map((e) => e.courseId).toSet();
                    final languages = courses.where((c) => c.courseType == 'language').toList();
                    final frameworks = courses.where((c) => c.courseType == 'framework').toList();

                    final selectedCourses = _selectedIndex == 0 ? languages : frameworks;

                    return _buildCourseGrid(context, selectedCourses, enrolledCourseIds);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseGrid(BuildContext context, List<Course> courses, Set<String> enrolledCourseIds) {
    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 2 / 2.5,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        final isEnrolled = enrolledCourseIds.contains(course.id);
        return CourseCard(course: course, isEnrolled: isEnrolled);
      },
    );
  }
}

class CourseCard extends StatelessWidget {
  final Course course;
  final bool isEnrolled;

  const CourseCard({super.key, required this.course, required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnrolled
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CourseDetailsPage(course: course)),
              );
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/course_images/${course.name.toLowerCase()}.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white10,
                            child: const Icon(Icons.code, size: 40, color: Colors.blueAccent),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              course.name,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${course.estimatedTimeHours} hours',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (isEnrolled)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Enrolled',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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
