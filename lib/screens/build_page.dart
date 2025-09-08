import 'dart:ui';
import 'package:codemate/components/build/build_page_landing.dart';
import 'package:codemate/models/project.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/screens/ide_page.dart';
import 'package:codemate/widgets/premium_sidebar.dart';
import 'package:codemate/screens/playground_page.dart';
import 'package:codemate/screens/learn_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:codemate/widgets/fancy_loader.dart';

class BuildPage extends ConsumerStatefulWidget {
  const BuildPage({super.key});

  @override
  ConsumerState<BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends ConsumerState<BuildPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(projectsProvider.notifier).fetchProjects());
  }

  void _navigateToCreateProject() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const BuildPageLanding()));
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0E12), Color(0xFF151821), Color(0xFF1A1D29)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundEffects(context),
            Row(
              children: [
                PremiumSidebar(
                  items: [
                    PremiumSidebarItem(
                      icon: Icons.home,
                      label: 'Home',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.play_arrow_rounded,
                      label: 'Playground',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlaygroundPage(),
                            ),
                          ),
                    ),
                    PremiumSidebarItem(
                      icon: Icons.construction_rounded,
                      label: 'Build',
                      onTap: () {},
                      selected: true,
                    ),
                    PremiumSidebarItem(
                      icon: Icons.school_rounded,
                      label: 'Learn',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LearnPage(),
                            ),
                          ),
                    ),
                  ],
                  topPadding: 12,
                ),
                Expanded(
                  child: SafeArea(
                    child:
                        projectsState.isLoading
                            ? const _BuildPageSkeleton()
                            : projectsState.error != null
                            ? Center(
                              child: Text(
                                'Error: ${projectsState.error}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            )
                            : _buildTwoPanelLayout(projectsState.projects),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundEffects(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Primary construction-themed glow - top left
        Positioned(
          top: screenSize.height * 0.1,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.15),
                  const Color(0xFFFF8C42).withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Secondary blue glow - bottom right
        Positioned(
          bottom: screenSize.height * 0.15,
          right: -150,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4DABF7).withOpacity(0.12),
                  const Color(0xFF339AF0).withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Tertiary warm glow - center right
        Positioned(
          top: screenSize.height * 0.4,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFAB005).withOpacity(0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoPanelLayout(List<Project> projects) {
    return Row(
      children: [
        // Left Panel - Overview and Stats
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeftPanelHeader(),
                const SizedBox(height: 32),
                _buildNewProjectButton(),
                const SizedBox(height: 32),
                _buildStatsCards(projects),
              ],
            ),
          ),
        ),
        // Right Panel - Projects List
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Recent Projects',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          '${projects.length}',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                Expanded(
                  child:
                      projects.isEmpty
                          ? _buildEmptyState()
                          : _buildProjectsList(projects),
                ),
              ],
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
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back to Home',
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'My Projects',
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your projects, all in one place',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildNewProjectButton() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToCreateProject,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'New Project',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start building with AI assistance',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(List<Project> projects) {
    final stackCounts = <String, int>{};
    for (final project in projects) {
      for (final stack in project.stack) {
        stackCounts[stack] = (stackCounts[stack] ?? 0) + 1;
      }
    }

    final topStacks =
        stackCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final recentProjects =
        projects
            .where((p) => DateTime.now().difference(p.updatedAt).inDays <= 7)
            .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Projects',
                value: projects.length.toString(),
                icon: Icons.folder_outlined,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Active This Week',
                value: recentProjects.toString(),
                icon: Icons.trending_up,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStackCard(topStacks.take(3).toList()),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackCard(List<MapEntry<String, int>> topStacks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.layers_outlined,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Popular Stacks',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topStacks.isEmpty)
            Text(
              'No stacks yet',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            )
          else
            ...topStacks.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: GoogleFonts.robotoMono(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_off_outlined,
                size: 60,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Projects Yet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to get started',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsList(List<Project> projects) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final project = projects[index];
        return ProjectCard(project: project);
      },
    );
  }
}

class _BuildPageSkeleton extends StatelessWidget {
  const _BuildPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Left panel skeleton
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                BigShimmer(width: 220, height: 36),
                SizedBox(height: 16),
                BigShimmer(width: 300, height: 20),
                SizedBox(height: 24),
                BigShimmer(
                  width: 260,
                  height: 120,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                SizedBox(height: 24),
                BigShimmer(width: 200, height: 18),
                SizedBox(height: 12),
                BigShimmer(width: 380, height: 80),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right panel skeleton
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  BigShimmer(width: 240, height: 24),
                  SizedBox(height: 16),
                  BigShimmer(width: double.infinity, height: 64),
                  SizedBox(height: 12),
                  BigShimmer(width: double.infinity, height: 64),
                  SizedBox(height: 12),
                  BigShimmer(width: double.infinity, height: 64),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectCard extends ConsumerWidget {
  final Project project;
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => IdePage(projectId: project.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.code,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        project.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(context, ref, project.id);
                        }
                      },
                      color: const Color(0xFF1F2937),
                      itemBuilder:
                          (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                dense: true,
                              ),
                            ),
                          ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  project.description,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                if (project.stack.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        project.stack
                            .take(3)
                            .map(
                              (stack) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Text(
                                  stack,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.white.withOpacity(0.4),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Updated ${DateFormat.yMMMd().format(project.updatedAt)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String projectId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project?'),
          content: const Text(
            'Are you sure you want to delete this project? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () {
                ref.read(projectsProvider.notifier).deleteProject(projectId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
