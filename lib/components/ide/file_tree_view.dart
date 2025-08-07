import 'package:codemate/models/project_file.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileTreeView extends ConsumerWidget {
  final String projectId;
  const FileTreeView({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectFilesState = ref.watch(projectFilesProvider(projectId));

    return Scaffold(
      body: Builder(
        builder: (context) {
          if (projectFilesState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (projectFilesState.error != null) {
            return Center(child: Text('Error: ${projectFilesState.error}'));
          }
          if (projectFilesState.files.isEmpty) {
            return const Center(child: Text('No files in this project yet.'));
          }
          final fileTree = _buildFileTree(projectFilesState.files, ref);
          return ListView(
            children: fileTree,
          );
        },
      ),
    );
  }

  List<Widget> _buildFileTree(List<ProjectFile> files, WidgetRef ref) {
    final codeViewController = ref.read(codeViewProvider.notifier);
    final Map<String, List<ProjectFile>> directoryMap = {};

    for (var file in files) {
      final parts = file.path.split('/');
      final directory = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('/')
          : '/';
      if (!directoryMap.containsKey(directory)) {
        directoryMap[directory] = [];
      }
      directoryMap[directory]!.add(file);
    }

    final sortedDirectories = directoryMap.keys.toList()..sort();
    final List<Widget> treeNodes = [];

    for (var directory in sortedDirectories) {
      treeNodes.add(
        ExpansionTile(
          title: Text(directory),
          leading: const Icon(Icons.folder),
          children: directoryMap[directory]!.map((file) {
            return ListTile(
              title: Text(file.path.split('/').last),
              leading: const Icon(Icons.description),
              onTap: () {
                codeViewController.openFile(file);
              },
            );
          }).toList(),
        ),
      );
    }
    return treeNodes;
  }
}
