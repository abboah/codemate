import 'package:codemate/models/project_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final codeViewProvider = ChangeNotifierProvider<CodeViewProvider>(
  (ref) => CodeViewProvider(),
);

class CodeViewProvider extends ChangeNotifier {
  ProjectFile? _activeFile;
  String _code = '';

  ProjectFile? get activeFile => _activeFile;
  String get code => _code;

  void openFile(ProjectFile file) {
    _activeFile = file;
    _code = file.content ?? '';
    notifyListeners();
  }

  void updateCode(String newCode) {
    _code = newCode;
    notifyListeners();
  }
}