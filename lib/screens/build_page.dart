import 'package:codemate/components/build/build_page_landing.dart';
import 'package:codemate/models/project.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:codemate/screens/agent_page.dart';
import 'package:codemate/widgets/two_column_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class BuildPage extends ConsumerStatefulWidget {
  const BuildPage({super.key});

  @override
  ConsumerState<BuildPage> createState() => _BuildPageState();
}

class _BuildPageState extends ConsumerState<BuildPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(projectsProvider).fetchProjects());
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);

    return TwoColumnLayout(
      pageTitle: 'Build',
      pageDescription:
          'Create, manage, and collaborate on your projects with the help of an AI agent.',
      buttonText: 'New Project',
      onButtonPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const BuildPageLanding(),
          ),
        );
      },
      rightColumnContent: projectsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : projectsState.error != null
              ? Center(child: Text(projectsState.error!))
              : projectsState.projects.isEmpty
                  ? Center(
                      child: Text(
                        'No projects yet. Create one to get started!',
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: projectsState.projects.length,
                      itemBuilder: (context, index) {
                        final project = projectsState.projects[index];
                        return ProjectCard(project: project);
                      },
                    ),
    );
  }
}

class ProjectCard extends ConsumerWidget {
  final Project project;
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          project.name,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            project.description,
            style: GoogleFonts.poppins(color: Colors.white70),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteConfirmation(context, ref, project.id);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AgentPage(projectId: project.id),
            ),
          );
        },
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                ref.read(projectsProvider).deleteProject(projectId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}