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
          .order('path', ascending: true);

      _files =
          (response as List).map((item) => ProjectFile.fromMap(item)).toList();
      _error = null;
    } catch (e) {
      _error = "Failed to fetch project files: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createFile(String path, String content) async {
    try {
      await _client.from('project_files').insert({
        'project_id': projectId,
        'path': path,
        'content': content,
      });
      await fetchFiles(); // Refresh the list
    } catch (e) {
      _error = "Failed to create file: $e";
      notifyListeners();
    }
  }

  Future<void> updateFileContent(String fileId, String newContent) async {
    try {
      await _client.from('project_files').update({
        'content': newContent,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', fileId);
      await fetchFiles(); // Refresh the list
    } catch (e) {
      _error = "Failed to update file: $e";
      notifyListeners();
    }
  }

  Future<void> deleteFile(String fileId) async {
    try {
      await _client.from('project_files').delete().eq('id', fileId);
      await fetchFiles(); // Refresh the list
    } catch (e) {
      _error = "Failed to delete file: $e";
      notifyListeners();
    }
  }
}
