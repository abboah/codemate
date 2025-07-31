import 'package:flutter/material.dart';

class CourseDetailsPage extends StatelessWidget {
  const CourseDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Details'),
      ),
      body: const Center(
        child: Text('Course details and enrollment button will be here.'),
      ),
    );
  }
}