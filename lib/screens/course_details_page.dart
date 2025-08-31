import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/enrolled_course_page.dart';
import 'package:codemate/widgets/topic_preview_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/build_page.dart';

class CourseDetailsPage extends ConsumerStatefulWidget {
  final Course course;
  const CourseDetailsPage({super.key, required this.course});

  @override
  ConsumerState<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends ConsumerState<CourseDetailsPage> {
  String _difficulty = 'beginner';
  String _learningStyle = 'visual';
  bool _isLoading = false;

  void _enroll() async {
    setState(() => _isLoading = true);
    try {
      final newEnrollment = await ref.read(enrollInCourseProvider({
        'course_id': widget.course.id,
        'difficulty': _difficulty,
        'learning_style': _learningStyle,
      }).future);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EnrolledCoursePage(
              course: widget.course,
              enrollment: newEnrollment,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enrolling: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(courseTopicsProvider(widget.course.id));
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
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
            child: Padding(
              padding: const EdgeInsets.only(top: kToolbarHeight + 8),
              child: screenWidth > 800
                  ? _buildDesktopLayout(topicsAsync)
                  : _buildMobileLayout(topicsAsync),
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
                    Expanded(
                      child: Text(
                        widget.course.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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

  Widget _buildDesktopLayout(AsyncValue<List<Topic>> topicsAsync) {
    return Padding(
      padding: const EdgeInsets.only(left: 70), // Accommodate sidebar width
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40.0),
              child: _buildLeftColumn(),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 32, 24, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.02),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _buildRightColumn(topicsAsync),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(AsyncValue<List<Topic>> topicsAsync) {
    return Padding(
      padding: const EdgeInsets.only(left: 70), // Accommodate sidebar width
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildLeftColumn(),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.02),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _buildRightColumn(topicsAsync),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/course_images/${widget.course.name.toLowerCase()}.png',
            height: 300,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.white10,
                child: Icon(Icons.code, size: 60, color: AppColors.accent),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.course.name,
          style: GoogleFonts.poppins(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.course.description,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),
        _buildDropdown('Difficulty', _difficulty, ['beginner', 'intermediate', 'advanced'], (val) {
          setState(() => _difficulty = val!);
        }),
        const SizedBox(height: 24),
        _buildDropdown('Learning Style', _learningStyle, ['visual', 'kinesthetic', 'auditory', 'reading/writing'], (val) {
          setState(() => _learningStyle = val!);
        }),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _isLoading ? null : _enroll,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const MiniWave(size: 20)
              : Text(
                  'Start Learning',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String title, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E1E1E),
            style: GoogleFonts.poppins(color: Colors.white),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: items.map<DropdownMenuItem<String>>((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Text(val[0].toUpperCase() + val.substring(1)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(AsyncValue<List<Topic>> topicsAsync) {
    return topicsAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              BigShimmer(width: 200, height: 16),
              SizedBox(height: 12),
              BigShimmer(width: 260, height: 14),
              SizedBox(height: 12),
              BigShimmer(width: 240, height: 14),
              SizedBox(height: 12),
              BigShimmer(width: 220, height: 14),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (topics) {
          return ListView.separated(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isProject = topic.topicType == 'project';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black.withOpacity(0.5),
                      builder: (context) => TopicPreviewModal(
                        topic: topic,
                        course: widget.course,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isProject
                                ? [
                                    Colors.amber.withOpacity(0.6),
                                    Colors.amber.withOpacity(0.3),
                                    Colors.amber.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.blueAccent.withOpacity(0.6),
                                    Colors.blueAccent.withOpacity(0.3),
                                    Colors.blueAccent.withOpacity(0.1),
                                  ],
                          ),
                          border: Border.all(
                            color: isProject
                                ? Colors.amber.withOpacity(0.3)
                                : Colors.blueAccent.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isProject ? Colors.amber : Colors.blueAccent).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isProject ? Icons.assignment_turned_in_outlined : Icons.menu_book_outlined,
                          color: isProject ? Colors.amber : Colors.blueAccent,
                          size: 24,
                        ),
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
                                fontSize: 15,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              topic.description,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  }
}
