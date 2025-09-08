import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/course_details_page.dart';
import 'package:codemate/widgets/pill_toggle_switch.dart';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/build_page.dart';
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
      body: Stack(
        children: [
          // Background gradient and main content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0F),
                  Color(0xFF0E0E15),
                  Color(0xFF12121A),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Column(
              children: [
                // leave space under custom app bar
                const SizedBox(height: kToolbarHeight + 8),
                // Toggle bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 104.0, vertical: 16.0),
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
                // Grid content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 80),
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
                ),
              ],
            ),
          ),
          // Custom AppBar shifted right to accommodate sidebar and match body gradient
          Positioned(
            left: 70,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                height: kToolbarHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A0A0F),
                      Color(0xFF0E0E15),
                      Color(0xFF12121A),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Browse Courses',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sidebar extending to the very top when collapsed, overlapping AppBar
          PremiumSidebar(
            topPadding: 16, // Reduced padding to start higher
            items: [
              PremiumSidebarItem(
                icon: Icons.home,
                label: 'Home',
                onTap: () => Navigator.of(context).maybePop(),
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.04),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
  supabase.storage
      .from('assets')
      .getPublicUrl('course_images/${course.name.toLowerCase()}.png'),
  fit: BoxFit.cover,

                      // child: Image.asset(
                      //   'assets/course_images/${course.name.toLowerCase()}.png',
                      //   fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent.withOpacity(0.3),
                                  Colors.blueAccent.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.code, size: 40, color: Colors.blueAccent),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                course.description.isNotEmpty 
                                    ? course.description 
                                    : 'Learn the fundamentals and advanced concepts',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${course.estimatedTimeHours}h',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ],
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
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enrolled',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Continue Learning',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
