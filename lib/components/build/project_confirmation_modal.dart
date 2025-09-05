import 'dart:ui';
import 'package:codemate/providers/projects_provider.dart';
import 'package:flutter/material.dart';
import 'package:codemate/components/build/brainstorm_modal.dart'; // Reusing ProjectAnalysis
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const Color seaBlue = Color(0xFF006994);

class ProjectConfirmationModal extends ConsumerStatefulWidget {
  final ProjectAnalysis analysis;

  const ProjectConfirmationModal({super.key, required this.analysis});

  @override
  _ProjectConfirmationModalState createState() =>
      _ProjectConfirmationModalState();
}

class _ProjectConfirmationModalState
    extends ConsumerState<ProjectConfirmationModal> {
  late ProjectAnalysis editableAnalysis;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the analysis to allow editing.
    editableAnalysis = ProjectAnalysis(
      projectTitle: widget.analysis.projectTitle,
      description: widget.analysis.description,
      suggestedStack: List.from(widget.analysis.suggestedStack),
      coreFeatures: List.from(widget.analysis.coreFeatures),
    );
  }

  void _addTech() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Technology'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'e.g., Flutter, Python, etc.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: seaBlue),
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

  Future<void> _confirmAndCreateProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final newProjectId = await ref
          .read(projectsProvider.notifier)
          .createProject(editableAnalysis);

      if (mounted && newProjectId != null) {
        Navigator.of(context).pop(newProjectId); // Pop with the new project ID
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create project.')),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Review the details below, then we can start building.",
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 32),
                          _buildTextFormField(
                            initialValue: editableAnalysis.projectTitle,
                            label: 'Project Title',
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'Title cannot be empty'
                                : null,
                            onSaved: (value) =>
                                editableAnalysis.projectTitle = value!,
                          ),
                          const SizedBox(height: 24),
                          _buildTextFormField(
                            initialValue: editableAnalysis.description,
                            label: 'Description',
                            maxLines: 4,
                            onSaved: (value) =>
                                editableAnalysis.description = value!,
                          ),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Tech Stack'),
                          _buildTechStack(),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Core Features'),
                          _buildFeaturesList(),
                        ],
                      ),
                    ),
                  ),
                  _buildActionBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Confirm Project Details',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required String initialValue,
    required String label,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(label),
        TextFormField(
          initialValue: initialValue,
          onSaved: onSaved,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: seaBlue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTechStack() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        ...editableAnalysis.suggestedStack.map((tech) => Chip(
              label: Text(tech, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
              backgroundColor: seaBlue.withOpacity(0.8),
              onDeleted: () =>
                  setState(() => editableAnalysis.suggestedStack.remove(tech)),
              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
            )),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16, color: Colors.white70),
          label: Text('Add', style: GoogleFonts.poppins(color: Colors.white70)),
          backgroundColor: Colors.white.withOpacity(0.1),
          onPressed: _addTech,
        )
      ],
    );
  }

  Widget _buildFeaturesList() {
    return Column(
      children: editableAnalysis.coreFeatures
          .map((feature) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_box_outline_blank, color: seaBlue),
                title: Text(feature, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                  onPressed: () => setState(
                      () => editableAnalysis.coreFeatures.remove(feature)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: seaBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _confirmAndCreateProject,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ))
                : const Icon(Icons.rocket_launch_outlined, size: 18),
            label: Text('Start Building', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.8),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
