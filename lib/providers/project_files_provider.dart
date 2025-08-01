import 'package:codemate/models/project_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final projectFilesProvider =
    ChangeNotifierProvider.family<ProjectFilesProvider, String>(
  (ref, projectId) => ProjectFilesProvider(projectId),
);

class ProjectFilesProvider extends ChangeNotifier {
  final String projectId;
  final SupabaseClient _client = Supabase.instance.client;

  ProjectFilesProvider(this.projectId) {
    fetchFiles();
  }

  List<ProjectFile> _files = [];
  bool _isLoading = false;
  String? _error;

  List<ProjectFile> get files => _files;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchFiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client
          .from('project_files')
          .select()
          .eq('project_id', projectId)
          .order('file_path', ascending: true);

      _files =
          (response as List).map((item) => ProjectFile.fromMap(item)).toList();
    } catch (e) {
      _error = "Failed to fetch project files: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
