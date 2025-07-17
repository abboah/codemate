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
  final Map<String, List<Map<String, dynamic>>> pathSubsections = {
    'Mobile App Development': [
      {'name': 'Flutter', 'icon': Icons.flutter_dash},
      {'name': 'React Native', 'icon': Icons.phone_android},
      {'name': 'Swift', 'icon': Icons.phone_iphone},
      {'name': 'Kotlin', 'icon': Icons.android},
    ],
    'Web Development': [
      {'name': 'HTML', 'icon': Icons.language},
      {'name': 'CSS', 'icon': Icons.style},
      {'name': 'JavaScript', 'icon': Icons.code},
      {'name': 'React', 'icon': Icons.web},
      {'name': 'Next.js', 'icon': Icons.web_asset},
    ],
    'AI & ML': [
      {'name': 'Python', 'icon': Icons.memory},
      {'name': 'TensorFlow', 'icon': Icons.bubble_chart},
      {'name': 'PyTorch', 'icon': Icons.scatter_plot},
      {'name': 'Data Science', 'icon': Icons.analytics},
    ],
    'Cybersecurity': [
      {'name': 'Network Security', 'icon': Icons.security},
      {'name': 'Ethical Hacking', 'icon': Icons.lock_open},
      {'name': 'Cryptography', 'icon': Icons.vpn_key},
    ],
    'Game Development': [
      {'name': 'Unity', 'icon': Icons.sports_esports},
      {'name': 'Unreal', 'icon': Icons.sports_esports},
      {'name': 'Godot', 'icon': Icons.sports_esports},
    ],
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
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 8,
        vertical: isDesktop ? 32 : 12,
      ),
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
    return Column(
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
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child:
                state.selectedTab == 0
                    ? _buildPathsSection(state, notifier)
                    : _buildLanguagesSection(state, notifier),
          ),
        ),
      ],
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
      color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                backgroundColor: Colors.blueAccent,
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
      color: Colors.blueGrey[900],
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
          color: isSelected ? Colors.blueAccent : Colors.transparent,
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.5,
      ),
      itemCount: filteredPaths.length,
      itemBuilder: (context, idx) {
        final path = filteredPaths[idx];
        final isCurrent = state.selectedPath == path;
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
                children: [
                  Row(
                    children: [
                      Icon(Icons.track_changes, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          path,
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
                  Text(
                    'Subsections:',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final sub in pathSubsections[path] ?? [])
                        _buildSubsectionChip(sub),
                    ],
                  ),
                  const Spacer(),
                  LinearProgressIndicator(
                    value: isCurrent ? state.currentPathProgress : 0.0,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white70,
                        ),
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

  Widget _buildSubsectionChip(Map<String, dynamic> sub) {
    return ActionChip(
      avatar: Icon(sub['icon'], color: Colors.white, size: 18),
      label: Text(
        sub['name'],
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      backgroundColor: Colors.blueGrey[700],
      onPressed: () {
        // Placeholder for showing courses/topics/quizzes
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.blueGrey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  sub['name'],
                  style: const TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Courses, topics, and quizzes coming soon!',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
        );
      },
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
            color: Colors.deepPurple[800],
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
