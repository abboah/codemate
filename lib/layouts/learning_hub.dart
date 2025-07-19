import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/learning_state_provider.dart';
import 'course_detail_page.dart';

class LearningHub extends ConsumerStatefulWidget {
  const LearningHub({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LearningHubState();
}

class _LearningHubState extends ConsumerState<LearningHub> {
  // Data for paths and languages
  final List<String> featuredPaths = [
    'Web Development',
    'Mobile App Development',
    'AI & ML',
    'Cybersecurity',
    'Game Development',
  ];

  // Enhanced path data with preferred paths and tooltips
  final Map<String, Map<String, dynamic>> pathData = {
    'Web Development': {
      'icon': Icons.web,
      'color': Colors.blue,
      'preferredPaths': [
        {
          'name': 'HTML/CSS/JS',
          'icon': Icons.language,
          'tooltip':
              'The foundation of web development. Start here for frontend basics.',
          'difficulty': 'Beginner',
          'popularity': 95,
        },
        {
          'name': 'React.js',
          'icon': Icons.web,
          'tooltip':
              'Most popular frontend framework. High demand in job market.',
          'difficulty': 'Intermediate',
          'popularity': 90,
        },
        {
          'name': 'Next.js',
          'icon': Icons.web_asset,
          'tooltip': 'Full-stack React framework. Perfect for modern web apps.',
          'difficulty': 'Advanced',
          'popularity': 85,
        },
        {
          'name': 'PHP/Laravel',
          'icon': Icons.code,
          'tooltip':
              'Server-side scripting. Great for dynamic websites and APIs.',
          'difficulty': 'Intermediate',
          'popularity': 75,
        },
      ],
    },
    'Mobile App Development': {
      'icon': Icons.phone_android,
      'color': Colors.green,
      'preferredPaths': [
        {
          'name': 'Flutter',
          'icon': Icons.flutter_dash,
          'tooltip':
              'Cross-platform development with single codebase. Growing rapidly.',
          'difficulty': 'Intermediate',
          'popularity': 88,
        },
        {
          'name': 'React Native',
          'icon': Icons.phone_android,
          'tooltip': 'JavaScript-based mobile development. Backed by Meta.',
          'difficulty': 'Intermediate',
          'popularity': 85,
        },
        {
          'name': 'Swift (iOS)',
          'icon': Icons.apple,
          'tooltip':
              'Native iOS development. Best performance and platform integration.',
          'difficulty': 'Advanced',
          'popularity': 80,
        },
        {
          'name': 'Kotlin (Android)',
          'icon': Icons.android,
          'tooltip':
              'Modern Android development. Google\'s preferred language.',
          'difficulty': 'Intermediate',
          'popularity': 82,
        },
      ],
    },
    'AI & ML': {
      'icon': Icons.psychology,
      'color': Colors.purple,
      'preferredPaths': [
        {
          'name': 'Python + TensorFlow',
          'icon': Icons.memory,
          'tooltip':
              'Industry standard for machine learning. Excellent ecosystem.',
          'difficulty': 'Intermediate',
          'popularity': 92,
        },
        {
          'name': 'PyTorch',
          'icon': Icons.scatter_plot,
          'tooltip': 'Research-focused ML framework. Great for deep learning.',
          'difficulty': 'Advanced',
          'popularity': 88,
        },
        {
          'name': 'Data Science',
          'icon': Icons.analytics,
          'tooltip':
              'Statistical analysis and visualization. High demand field.',
          'difficulty': 'Intermediate',
          'popularity': 85,
        },
        {
          'name': 'Computer Vision',
          'icon': Icons.visibility,
          'tooltip': 'Image and video processing. Applications in automation.',
          'difficulty': 'Advanced',
          'popularity': 78,
        },
      ],
    },
    'Cybersecurity': {
      'icon': Icons.security,
      'color': Colors.red,
      'preferredPaths': [
        {
          'name': 'Network Security',
          'icon': Icons.security,
          'tooltip':
              'Protecting networks and systems. Foundation of cybersecurity.',
          'difficulty': 'Intermediate',
          'popularity': 85,
        },
        {
          'name': 'Ethical Hacking',
          'icon': Icons.lock_open,
          'tooltip':
              'Penetration testing and vulnerability assessment. High paying.',
          'difficulty': 'Advanced',
          'popularity': 88,
        },
        {
          'name': 'Cloud Security',
          'icon': Icons.cloud_circle,
          'tooltip':
              'Securing cloud infrastructure. Critical for modern businesses.',
          'difficulty': 'Advanced',
          'popularity': 90,
        },
        {
          'name': 'Cryptography',
          'icon': Icons.vpn_key,
          'tooltip':
              'Mathematical foundations of security. Highly specialized.',
          'difficulty': 'Expert',
          'popularity': 70,
        },
      ],
    },
    'Game Development': {
      'icon': Icons.sports_esports,
      'color': Colors.orange,
      'preferredPaths': [
        {
          'name': 'Unity + C#',
          'icon': Icons.sports_esports,
          'tooltip': 'Most popular game engine. Great for 2D and 3D games.',
          'difficulty': 'Intermediate',
          'popularity': 90,
        },
        {
          'name': 'Unreal Engine',
          'icon': Icons.terrain,
          'tooltip': 'AAA game development. Excellent for high-end graphics.',
          'difficulty': 'Advanced',
          'popularity': 85,
        },
        {
          'name': 'Godot',
          'icon': Icons.games,
          'tooltip': 'Open-source game engine. Great for indie developers.',
          'difficulty': 'Beginner',
          'popularity': 75,
        },
        {
          'name': 'Mobile Games',
          'icon': Icons.phone_android,
          'tooltip':
              'Largest gaming market. Focus on casual and hyper-casual games.',
          'difficulty': 'Intermediate',
          'popularity': 88,
        },
      ],
    },
  };

  final List<Map<String, dynamic>> languages = [
    {'name': 'Python', 'icon': Icons.memory, 'progress': 0.7},
    {'name': 'JavaScript', 'icon': Icons.code, 'progress': 0.5},
    {'name': 'Dart', 'icon': Icons.flutter_dash, 'progress': 0.3},
    {'name': 'Java', 'icon': Icons.coffee, 'progress': 0.2},
    {'name': 'Go', 'icon': Icons.bubble_chart, 'progress': 0.1},
  ];

  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final learningState = ref.watch(learningStateProvider);
    final notifier = ref.read(learningStateProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width > 900;
    return Container(
      color: Colors.transparent,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child:
            learningState.pageIndex == 0
                ? _buildHub(context, notifier, learningState, isDesktop)
                : CourseDetailPage(
                  path: learningState.selectedPath,
                  language: learningState.selectedLanguage,
                  onBack: notifier.goToHub,
                ),
      ),
    );
  }

  Widget _buildHub(
    BuildContext context,
    LearningStateNotifier notifier,
    LearningState state,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.10), // match dashboard
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Smart Path Display
                  _buildSmartPathDisplay(context, isDesktop, state),
                  const SizedBox(height: 24),
                  // Tabs
                  _buildTabs(state),
                  const SizedBox(height: 16),
                  // Search/filter
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  // Main content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child:
                        state.selectedTab == 0
                            ? _buildPathsSection(state, notifier)
                            : _buildLanguagesSection(state, notifier),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartPathDisplay(
    BuildContext context,
    bool isDesktop,
    LearningState state,
  ) {
    if (state.selectedPath == null) {
      return _buildEmptyStateCTA(context);
    }
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
        child: Row(
          children: [
            Icon(Icons.track_changes, color: Colors.blueAccent, size: 40),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.selectedPath!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.currentPathProgress,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${(state.currentPathProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // Placeholder for continuing path
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Continue learning!')),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCTA(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      //  color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.orangeAccent, size: 40),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'No Learning Path Selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Get started by choosing a path below or explore trending fields!',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {},
              child: const Text('Choose a Path'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(LearningState state) {
    return Row(
      children: [
        _buildTab('Paths', 0, state),
        const SizedBox(width: 12),
        _buildTab('Languages', 1, state),
      ],
    );
  }

  Widget _buildTab(String label, int index, LearningState state) {
    final isSelected = state.selectedTab == index;
    return GestureDetector(
      onTap: () => ref.read(learningStateProvider.notifier).selectTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search paths or languages...',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
      style: const TextStyle(color: Colors.white),
      onChanged: (val) => setState(() => searchQuery = val),
    );
  }

  Widget _buildPathsSection(
    LearningState state,
    LearningStateNotifier notifier,
  ) {
    final filteredPaths =
        featuredPaths
            .where((p) => p.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.3,
      ),
      itemCount: filteredPaths.length,
      itemBuilder: (context, idx) {
        final path = filteredPaths[idx];
        final pathInfo = pathData[path]!;
        final isCurrent = state.selectedPath == path;
        return _buildPathCard(path, pathInfo, isCurrent, notifier, state);
      },
    );
  }

  Widget _buildPathCard(
    String path,
    Map<String, dynamic> pathInfo,
    bool isCurrent,
    LearningStateNotifier notifier,
    LearningState state,
  ) {
    final preferredPaths =
        pathInfo['preferredPaths'] as List<Map<String, dynamic>>;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blueAccent : Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border:
            isCurrent
                ? Border.all(color: Colors.white.withOpacity(0.2), width: 2)
                : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          notifier.selectPath(path);
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(pathInfo['icon'], color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      path,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preferred Paths Section
              Text(
                'Preferred Industry Paths:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Preferred Paths Wrap
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    preferredPaths.map((preferredPath) {
                      return _buildPreferredPathContainer(preferredPath);
                    }).toList(),
              ),

              const SizedBox(height: 20),

              // Progress and Action
              LinearProgressIndicator(
                value: isCurrent ? state.currentPathProgress : 0.0,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    isCurrent ? 'In Progress' : 'Start Path',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (!isCurrent)
                    Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferredPathContainer(Map<String, dynamic> preferredPath) {
    return Tooltip(
      message: preferredPath['tooltip'],
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              _showPreferredPathDetails(preferredPath);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(preferredPath['icon'], color: Colors.white, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    preferredPath['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(preferredPath['difficulty']),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      preferredPath['difficulty'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      case 'Expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showPreferredPathDetails(Map<String, dynamic> preferredPath) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.blueGrey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(preferredPath['icon'], color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    preferredPath['name'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preferredPath['tooltip'],
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Difficulty: ',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(preferredPath['difficulty']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        preferredPath['difficulty'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Popularity: ',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    Text(
                      '${preferredPath['popularity']}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: preferredPath['popularity'] / 100,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // TODO: Navigate to specific path course
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Starting ${preferredPath['name']} course!',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text('Start Learning'),
              ),
            ],
          ),
    );
  }

  Widget _buildLanguagesSection(
    LearningState state,
    LearningStateNotifier notifier,
  ) {
    final filteredLangs =
        languages
            .where(
              (l) =>
                  l['name'].toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 2.2,
      ),
      itemCount: filteredLangs.length,
      itemBuilder: (context, idx) {
        final lang = filteredLangs[idx];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.blueGrey[800], // match dashboard
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              notifier.selectLanguage(lang['name']);
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(lang['icon'], color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lang['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: lang['progress'],
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${(lang['progress'] * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
