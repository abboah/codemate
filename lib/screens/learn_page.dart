import 'package:codemate/providers/courses_provider.dart';
import 'package:codemate/widgets/two_column_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/screens/course_details_page.dart';

class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(coursesProvider).fetchCourses());
  }

  @override
  Widget build(BuildContext context) {
    final coursesState = ref.watch(coursesProvider);

    return TwoColumnLayout(
      pageTitle: 'Learn',
      pageDescription: 'Explore guided learning paths and master new skills at your own pace.',
      buttonText: 'Browse Courses',
      onButtonPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CourseDetailsPage()),
        );
      },
      rightColumnContent: coursesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : coursesState.error != null
              ? Center(child: Text(coursesState.error!))
              : coursesState.courses.isEmpty
                  ? Center(
                      child: Text(
                        'No courses available yet.',
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: coursesState.courses.length,
                      itemBuilder: (context, index) {
                        final course = coursesState.courses[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CourseDetailsPage(),
                              ),
                            );
                          },
                          child: ListTile(
                            title: Text(course.title),
                            subtitle: Text(course.description),
                          ),
                        );
                      },
                    ),
    );
  }
}
