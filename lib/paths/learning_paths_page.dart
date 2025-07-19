import 'package:codemate/layouts/background_pattern.dart';
import 'package:codemate/layouts/desktop_sidebar.dart';
import 'package:codemate/layouts/learning_hub.dart';
import 'package:codemate/layouts/top_appbar.dart';
import 'package:flutter/material.dart';

class LearningPathsPage extends StatefulWidget {
  const LearningPathsPage({super.key});

  @override
  State<LearningPathsPage> createState() => _LearningPathsPageState();
}

class _LearningPathsPageState extends State<LearningPathsPage> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundPattern(),
          SafeArea(
            child: Column(
              children: [
                TopAppbar(isDesktop: isDesktop),
                Expanded(
                  child: Row(
                    children: [
                      if (isDesktop)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: DesktopSidebar(),
                        ),
                      // Main content scrollable only
                      Expanded(child: LearningHub()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(painter: BackgroundPatternPainter()),
    );
  }

  Widget _buildPath(BuildContext context, bool isDesktop) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text('Path ${index + 1}'),
                    subtitle: Text('Description for Path ${index + 1}'),
                    onTap: () {
                      // Handle path selection
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
