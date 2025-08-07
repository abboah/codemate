import 'dart:ui';
import 'package:codemate/components/build/build_page_landing.dart';
import 'package:codemate/models/project.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/screens/ide_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Define the new color scheme
const Color seaBlue = Color(0xFF006994);

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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BuildPageLanding()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // Enforce black background
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Jump right back into your projects, or start something new.",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: projectsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : projectsState.error != null
                      ? Center(
                          child: Text(
                          'Error: ${projectsState.error}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ))
                      : projectsState.projects.isEmpty
                          ? _buildEmptyState(context)
                          : _buildProjectsGrid(projectsState.projects),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back to Home',
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Projects',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Your projects, all in one place.',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _navigateToCreateProject,
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: seaBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 80, color: Colors.white38),
          const SizedBox(height: 24),
          Text(
            'No Projects Yet',
            style: GoogleFonts.poppins(
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Click "New Project" to start building with the AI agent.',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsGrid(List<Project> projects) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        childAspectRatio: 1.8,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return ProjectCard(project: project);
      },
    );
  }
}

class ProjectCard extends ConsumerWidget {
  final Project project;
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => IdePage(projectId: project.id),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          project.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white70),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteConfirmation(context, ref, project.id);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                              title: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      project.description,
                      style: GoogleFonts.poppins(color: Colors.white70, height: 1.5),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (project.stack.isNotEmpty)
                        Expanded(
                          child: Text(
                            'Stack: ${project.stack.join(', ')}',
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        'Updated ${DateFormat.yMMMd().format(project.updatedAt)}',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String projectId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project?'),
          content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
