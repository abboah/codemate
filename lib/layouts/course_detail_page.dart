import 'package:flutter/material.dart';

class CourseDetailPage extends StatelessWidget {
  final String? path;
  final String? language;
  final VoidCallback onBack;
  const CourseDetailPage({
    super.key,
    this.path,
    this.language,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final title = path ?? language ?? 'Course';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: Text(
              'Course details, topics, and quizzes for $title will appear here. (Backend integration coming soon!)',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
