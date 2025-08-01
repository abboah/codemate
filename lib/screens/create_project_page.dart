import 'package:codemate/components/build/build_page_landing.dart';
import 'package:flutter/material.dart';

class CreateProjectPage extends StatelessWidget {
  const CreateProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a New Project'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: const BuildPageLanding(),
    );
  }
}
