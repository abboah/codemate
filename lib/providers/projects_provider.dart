import 'dart:convert';
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

  Future<String?> startPlanningSession(
      String sessionType, String rawInput) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client.from('planning_sessions').insert({
        'user_id': userId,
        'session_type': sessionType,
        'raw_input': rawInput,
        'status': 'active',
      }).select('id');

      final sessionId = response[0]['id'];
      return sessionId;
    } catch (e) {
      _error = 'Failed to start planning session: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePlanningSession(
      String sessionId, ProjectAnalysis analysis) async {
    try {
      await _client.from('planning_sessions').update({
        'analyzed_output': jsonEncode({
          'projectTitle': analysis.projectTitle,
          'description': analysis.description,
          'suggestedStack': analysis.suggestedStack,
          'coreFeatures': analysis.coreFeatures,
        }),
      }).eq('id', sessionId);
    } catch (e) {
      _error = 'Failed to update planning session: $e';
      notifyListeners();
    }
  }

  Future<String?> createProjectFromSession(
      String sessionId, ProjectAnalysis analysis) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client.from('projects').insert({
        'name': analysis.projectTitle,
        'description': analysis.description,
        'user_id': userId,
        'planning_session_id': sessionId,
      }).select('id');

      final newProjectId = response[0]['id'];

      await _client
          .from('planning_sessions')
          .update({'status': 'completed'}).eq('id', sessionId);

      await fetchProjects();
      return newProjectId;
    } catch (e) {
      _error = 'Failed to create project: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
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

  Project? getProjectById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteProject(String projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _client.from('projects').delete().eq('id', projectId);
      await fetchProjects();
    } catch (e) {
      _error = 'Failed to delete project: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}