import 'package:codemate/providers/learn_provider.dart';
import 'package:codemate/screens/enrolled_course_page.dart';
import 'package:codemate/widgets/topic_interaction_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: screenWidth > 800
          ? _buildDesktopLayout(topicsAsync)
          : _buildMobileLayout(topicsAsync),
    );
  }

  Widget _buildDesktopLayout(AsyncValue<List<Topic>> topicsAsync) {
    return Row(
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
          child: _buildRightColumn(topicsAsync),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(AsyncValue<List<Topic>> topicsAsync) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildLeftColumn(),
          ),
          _buildRightColumn(topicsAsync),
        ],
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
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: topicsAsync.when(
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
          return ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isProject = topic.topicType == 'project';
              return ListTile(
                onTap: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.5),
                    builder: (context) => TopicInteractionModal(topic: topic),
                  );
                },
                leading: Icon(
                  isProject ? Icons.assignment_turned_in : Icons.notes,
                  color: isProject ? Colors.amber : AppColors.accent,
                ),
                title: Text(
                  topic.title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                ),
                subtitle: Text(
                  topic.description,
                  style: GoogleFonts.poppins(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
