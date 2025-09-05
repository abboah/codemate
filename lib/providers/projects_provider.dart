import 'package:codemate/components/build/brainstorm_modal.dart';
import 'package:codemate/models/project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final projectsProvider = ChangeNotifierProvider((ref) => ProjectsProvider());

class ProjectsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  List<Project> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Project? getProjectById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('projects')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _projects =
          (response as List).map((item) => Project.fromMap(item)).toList();
    } catch (e) {
      _error = 'Failed to fetch projects: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createProject(ProjectAnalysis analysis) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client.from('projects').insert({
        'name': analysis.projectTitle,
        'description': analysis.description,
        'stack': analysis.suggestedStack,
        'user_id': userId,
      }).select('id');

      final newProjectId = response[0]['id'];
      await fetchProjects(); // Refresh the list to include the new project
      return newProjectId;
    } catch (e) {
      _error = 'Failed to create project: $e';
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProject(String projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _client.from('projects').delete().eq('id', projectId);
      _projects.removeWhere((p) => p.id == projectId); // Optimistic update
    } catch (e) {
      _error = 'Failed to delete project: $e';
      fetchProjects(); // Re-fetch to correct state on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
