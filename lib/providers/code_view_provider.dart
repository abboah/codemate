import 'package:codemate/models/project_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CodeViewState {
  final List<ProjectFile> openFiles;
  final int activeFileIndex;

  CodeViewState({
    this.openFiles = const [],
    this.activeFileIndex = -1,
  });

  CodeViewState copyWith({
    List<ProjectFile>? openFiles,
    int? activeFileIndex,
  }) {
    return CodeViewState(
      openFiles: openFiles ?? this.openFiles,
      activeFileIndex: activeFileIndex ?? this.activeFileIndex,
    );
  }
}

final codeViewProvider =
    StateNotifierProvider.autoDispose<CodeViewNotifier, CodeViewState>(
  (ref) => CodeViewNotifier(),
);

class CodeViewNotifier extends StateNotifier<CodeViewState> {
  CodeViewNotifier() : super(CodeViewState());

  void openFile(ProjectFile file) {
    final openFiles = state.openFiles;
    // Check if the file is already open
    final existingIndex = openFiles.indexWhere((f) => f.id == file.id);

    if (existingIndex != -1) {
      // If it is, just make it active
      state = state.copyWith(activeFileIndex: existingIndex);
    } else {
      // If not, add it to the list and make it active
      final newOpenFiles = [...openFiles, file];
      state = state.copyWith(
        openFiles: newOpenFiles,
        activeFileIndex: newOpenFiles.length - 1,
      );
    }
  }

  void closeFile(int index) {
    final openFiles = List<ProjectFile>.from(state.openFiles);
    openFiles.removeAt(index);

    int newActiveIndex = state.activeFileIndex;
    if (index < newActiveIndex) {
      newActiveIndex--;
    } else if (index == newActiveIndex) {
      newActiveIndex = openFiles.isNotEmpty ? (index > 0 ? index - 1 : 0) : -1;
    }

    state = state.copyWith(
      openFiles: openFiles,
      activeFileIndex: newActiveIndex,
    );
  }

  void setActiveFile(int index) {
    state = state.copyWith(activeFileIndex: index);
  }
}
