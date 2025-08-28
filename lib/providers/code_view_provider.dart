import 'package:codemate/models/project_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final codeViewProvider = ChangeNotifierProvider<CodeViewProvider>(
  (ref) => CodeViewProvider(),
);

class CodeViewProvider extends ChangeNotifier {
  // Open tabs in order
  final List<ProjectFile> _openFiles = [];
  // Active file id (from _openFiles)
  String? _activeFileId;
  // In-memory buffers per file id
  final Map<String, String> _buffers = {};

  List<ProjectFile> get openFiles => List.unmodifiable(_openFiles);
  ProjectFile? get activeFile {
    if (_openFiles.isEmpty) return null;
    final id = _activeFileId;
    if (id == null) return _openFiles.last;
    final idx = _openFiles.indexWhere((f) => f.id == id);
    if (idx == -1) return _openFiles.last;
    return _openFiles[idx];
  }
  String get code {
    final af = activeFile;
    if (af == null) return '';
    return _buffers[af.id] ?? af.content;
  }

  void openFile(ProjectFile file) {
    final existingIndex = _openFiles.indexWhere((f) => f.id == file.id);
    if (existingIndex == -1) {
      _openFiles.add(file);
      _buffers[file.id] = file.content;
    } else {
      // Update reference if path/content changed
      _openFiles[existingIndex] = file;
      _buffers[file.id] ??= file.content;
    }
    _activeFileId = file.id;
    notifyListeners();
  }

  void switchTab(String fileId) {
    if (_openFiles.any((f) => f.id == fileId)) {
      _activeFileId = fileId;
      notifyListeners();
    }
  }

  void closeTab(String fileId) {
    final idx = _openFiles.indexWhere((f) => f.id == fileId);
    if (idx == -1) return;
    final wasActive = (_activeFileId == fileId);
    _openFiles.removeAt(idx);
    _buffers.remove(fileId);
    if (wasActive) {
      if (_openFiles.isEmpty) {
        _activeFileId = null;
      } else {
        final nextIdx = idx > 0 ? idx - 1 : 0;
        _activeFileId = _openFiles[nextIdx].id;
      }
    }
    notifyListeners();
  }

  void updateCode(String newCode) {
    final af = activeFile;
    if (af == null) return;
    _buffers[af.id] = newCode;
    notifyListeners();
  }
}