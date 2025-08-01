import 'dart:ui';
import 'package:codemate/providers/projects_provider.dart';
import 'package:flutter/material.dart';
import 'package:codemate/components/build/brainstorm_modal.dart'; // Using the same ProjectAnalysis
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectConfirmationModal extends ConsumerStatefulWidget {
  final ProjectAnalysis analysis;
  final String sessionId;

  const ProjectConfirmationModal(
      {super.key, required this.analysis, required this.sessionId});

  @override
  _ProjectConfirmationModalState createState() =>
      _ProjectConfirmationModalState();
}

class _ProjectConfirmationModalState
    extends ConsumerState<ProjectConfirmationModal> {
  late ProjectAnalysis editableAnalysis;

  @override
  void initState() {
    super.initState();
    editableAnalysis = ProjectAnalysis.copy(widget.analysis);
  }

  void _removeTech(String tech) {
    setState(() {
      editableAnalysis.suggestedStack.remove(tech);
    });
  }

  void _addTech() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Technology'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Technology name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  editableAnalysis.suggestedStack.add(controller.text);
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _removeFeature(String feature) {
    setState(() {
      editableAnalysis.coreFeatures.remove(feature);
    });
  }

  void _confirmAndCreateProject() async {
    final newProjectId = await ref
        .read(projectsProvider)
        .createProjectFromSession(widget.sessionId, editableAnalysis);

    if (newProjectId != null) {
      Navigator.of(context).pop(newProjectId); // Pop with the new project ID
    } else {
      // Handle error case
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create project.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog.fullscreen(
        backgroundColor: Colors.black.withOpacity(0.5),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Confirm Project Details'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700),
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Here's what we came up with.",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Review and edit the details below, then we can start building.",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextFormField(
                      label: 'Project Title',
                      initialValue: editableAnalysis.projectTitle,
                      onChanged: (value) =>
                          editableAnalysis.projectTitle = value,
                    ),
                    const SizedBox(height: 24),
                    _buildTextFormField(
                      label: 'Description',
                      initialValue: editableAnalysis.description,
                      onChanged: (value) =>
                          editableAnalysis.description = value,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tech Stack'),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: editableAnalysis.suggestedStack
                          .map((tech) => Chip(
                                label: Text(tech),
                                onDeleted: () => _removeTech(tech),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                labelStyle:
                                    const TextStyle(color: Colors.white),
                                deleteIconColor: Colors.white70,
                              ))
                          .toList(),
                    ),
                    TextButton.icon(
                      onPressed: _addTech,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Technology'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Core Features'),
                    ...editableAnalysis.coreFeatures
                        .map((feature) => ListTile(
                              dense: true,
                              title: Text(feature,
                                  style: const TextStyle(color: Colors.white)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.white70),
                                onPressed: () => _removeFeature(feature),
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Back to Planning'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _confirmAndCreateProject,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Start Building'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }
}