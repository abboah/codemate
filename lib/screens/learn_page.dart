import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/browse_courses_page.dart';
import 'package:codemate/screens/enrolled_course_page.dart';
import 'package:codemate/widgets/app_showcase_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';
import 'package:codemate/screens/home_screen.dart';
import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/providers/tour_provider.dart';
import 'package:codemate/components/help_tour_button.dart';
import 'package:showcaseview/showcaseview.dart';

class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  bool _showcaseStarted = false;

  @override
  Widget build(BuildContext context) {
    final tour = ref.read(tourProvider);
    final enrolledCoursesAsync = ref.watch(enrolledCoursesDetailsProvider);

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_showcaseStarted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ShowCaseWidget.of(showcaseContext).startShowCase([
              
              tour.learnEnrolledKey,
              tour.learnProgressKey,
              tour.learnCourseListKey,
            ]);
          });
          _showcaseStarted = true;
        }
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            final profile = await ref.read(userProfileProvider.future);
            if (!context.mounted) return;
            if (profile != null) {
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
                (route) => false,
              );
            } else {
              nav.popUntil((route) => route.isFirst);
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F0F11),
            body: SafeArea(
              child: Stack(
                children: [
                  // Pale background with subtle gradients
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(-0.8, -0.6),
                        radius: 1.5,
                        colors: [
                          Color(0xFF1A1A1E),
                          Color(0xFF141418),
                          Color(0xFF0F0F11),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.8, 0.6),
                        radius: 1.2,
                        colors: [
                          Color(0xFF18181C),
                          Color(0xFF141416),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Main content
                  Row(
                    children: [
                      // Premium Sidebar
                      PremiumSidebar(
                        items: [
                          PremiumSidebarItem(
                            icon: Icons.home,
                            label: 'Home',
                            onTap: () async {
                              final profile = await ref.read(userProfileProvider.future);
                              if (!context.mounted) return;
                              if (profile != null) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                          PremiumSidebarItem(
                            icon: Icons.play_arrow_rounded,
                            label: 'Playground',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaygroundPage()));
                            },
                          ),
                          PremiumSidebarItem(
                            icon: Icons.construction_rounded,
                            label: 'Build',
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const BuildPage()));
                            },
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
                      // Main content area
                      Expanded(
                        child: _buildTwoPanelLayout(context, ref, enrolledCoursesAsync),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            floatingActionButton: HelpTourButton(
              tourKeys: [
                tour.learnCourseListKey,
                tour.learnEnrolledKey,
                tour.learnProgressKey,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTwoPanelLayout(BuildContext context, WidgetRef ref, AsyncValue<List<EnrolledCourseDetails>> enrolledCoursesAsync) {
        final tour = ref.read(tourProvider);

    return Row(
      children: [
        // Left panel - Header and Stats
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        final profile = await ref.read(userProfileProvider.future);
                        if (!context.mounted) return;
                        if (profile != null) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
                            (route) => false,
                          );
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLeftPanelHeader(),
                const SizedBox(height: 32),
                     Showcase.withWidget(
            key: tour.learnCourseListKey,
            container: AppShowcaseWidget(
              title: 'Browse Languages and Frameworks',
              description: 'Click here to enroll in a course. Multiple Languages and Frameworks from Beginner to Advanced programmers',
            ),
          height: 150, width: 250,child: _buildBrowseCoursesButton(context),),
                const SizedBox(height: 40),
                // Stats section header
                Text(
                  'Learning Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                  Showcase.withWidget(
            key: tour.learnProgressKey,
            container: AppShowcaseWidget(
              title: 'Progress Overview',
              description: 'Once you have enrolled in a course you can easily view your overall stats and progress from here',
            ),
          height: 150, width: 250,child: _buildStatsCards(ref, enrolledCoursesAsync)),
                const Spacer(),
              ],
            ),
          ),
        ),
        // Vertical divider
        Container(
          width: 1,
          color: Colors.white.withOpacity(0.1),
        ),
        // Right panel - Enrolled courses
        Expanded(
          flex: 1,
          child: Showcase.withWidget(
            key: tour.learnEnrolledKey,
            container: AppShowcaseWidget(
              title: 'Enrolled Courses',
              description: 'Once you have enrolled in a course you can easily access and continue them from here',
            ),
          height: 150, width: 250,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Learning Journey',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Continue where you left off',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: enrolledCoursesAsync.when(
                      loading: () => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            BigShimmer(width: 260, height: 14),
                            SizedBox(height: 12),
                            BigShimmer(width: 220, height: 14),
                            SizedBox(height: 12),
                            BigShimmer(width: 240, height: 14),
                          ],
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error loading courses: $err',
                          style: GoogleFonts.poppins(color: Colors.red.shade300),
                        ),
                      ),
                      data: (enrolledCourses) {
                        if (enrolledCourses.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No courses enrolled yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start your learning journey today',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: enrolledCourses.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final details = enrolledCourses[index];
                            return EnrolledCourseCard(details: details);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanelHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learn',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore guided learning paths and master new skills at your own pace',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white60,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseCoursesButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BrowseCoursesPage()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Browse Courses',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(WidgetRef ref, AsyncValue<List<EnrolledCourseDetails>> enrolledCoursesAsync) {
    return enrolledCoursesAsync.when(
      loading: () => Column(
        children: [
          _buildStatCardShimmer(),
          const SizedBox(height: 16),
          _buildStatCardShimmer(),
          const SizedBox(height: 16),
          _buildStatCardShimmer(),
        ],
      ),
      error: (err, stack) => Container(),
      data: (enrolledCourses) {
        // Calculate metrics
        final totalCourses = enrolledCourses.length;
        
        // For each enrollment, watch the topic status to calculate progress
        if (totalCourses == 0) {
          return Column(
            children: [
              _buildStatCard(
                'Total Courses',
                '0',
                Icons.library_books_rounded,
                const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Avg Progress',
                '0%',
                Icons.trending_up_rounded,
                const Color(0xFF059669),
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Learning Streak',
                '0 days',
                Icons.local_fire_department_rounded,
                const Color(0xFFDC2626),
              ),
            ],
          );
        }
        
        // Mock learning streak (would be calculated from actual activity data)
        final learningStreak = totalCourses > 0 ? 7 : 0;

        return Column(
          children: [
            _buildStatCard(
              'Total Courses',
              totalCourses.toString(),
              Icons.library_books_rounded,
              const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 16),
            _buildProgressCard(ref, enrolledCourses),
            const SizedBox(height: 16),
            _buildStatCard(
              'Learning Streak',
              '${learningStreak} days',
              Icons.local_fire_department_rounded,
              const Color(0xFFDC2626),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressCard(WidgetRef ref, List<EnrolledCourseDetails> enrolledCourses) {
    if (enrolledCourses.isEmpty) {
      return _buildStatCard(
        'Avg Progress',
        '0%',
        Icons.trending_up_rounded,
        const Color(0xFF059669),
      );
    }
    
    // Get all topic statuses for enrolled courses
    final topicStatusFutures = enrolledCourses.map(
      (course) => ref.read(topicStatusProvider(course.enrollment.id).future)
    ).toList();
    
    return FutureBuilder<List<List<UserTopicStatus>>>(
      future: Future.wait(topicStatusFutures),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildStatCardShimmer();
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildStatCard(
            'Avg Progress',
            '0%',
            Icons.trending_up_rounded,
            const Color(0xFF059669),
          );
        }
        
        // Calculate average progress
        double totalProgress = 0;
        int totalCourses = snapshot.data!.length;
        
        for (final statuses in snapshot.data!) {
          if (statuses.isNotEmpty) {
            final completed = statuses.where((s) => s.status == 'completed').length;
            final inProgress = statuses.where((s) => s.status == 'in_progress').length;
            final totalTopics = statuses.length;
            
            if (totalTopics > 0) {
              final courseProgress = ((completed * 10 + inProgress * 5) / (totalTopics * 10)) * 100;
              totalProgress += courseProgress;
            }
          }
        }
        
        final avgProgress = totalCourses > 0 ? totalProgress / totalCourses : 0;
        
        return _buildStatCard(
          'Avg Progress',
          '${avgProgress.toStringAsFixed(0)}%',
          Icons.trending_up_rounded,
          const Color(0xFF059669),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                BigShimmer(width: 80, height: 24),
                SizedBox(height: 4),
                BigShimmer(width: 120, height: 14),
              ],
            ),
          ),
        ],
      ),
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
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Course image with gradient overlay
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withOpacity(0.2),
                    AppColors.accent.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.asset(
                  'assets/course_images/${details.course.name.toLowerCase()}.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(0.3),
                            AppColors.accent.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.code_rounded,
                        size: 30,
                        color: AppColors.accent,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Course details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          details.course.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      // Course type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: details.course.courseType == 'language' 
                              ? const Color(0xFF4F46E5).withOpacity(0.2)
                              : const Color(0xFF059669).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: details.course.courseType == 'language'
                                ? const Color(0xFF4F46E5).withOpacity(0.3)
                                : const Color(0xFF059669).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          details.course.courseType == 'language' ? 'Language' : 'Framework',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: details.course.courseType == 'language'
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  topicStatusAsync.when(
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BigShimmer(height: 6, width: 200),
                        SizedBox(height: 8),
                        BigShimmer(height: 12, width: 100),
                      ],
                    ),
                    error: (err, stack) => Text(
                      'Error loading progress',
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade300,
                        fontSize: 12,
                      ),
                    ),
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
                          // Progress bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: progress / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.accent,
                                          AppColors.accent.withOpacity(0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${progress.toStringAsFixed(0)}% Complete',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$completed/$totalTopics topics',
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Arrow and menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      ref.read(deleteEnrollmentProvider(details.enrollment.id).future);
                    }
                  },
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                  color: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade300,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Delete Course',
                            style: GoogleFonts.poppins(
                              color: Colors.red.shade300,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
