import 'package:codemate/models/project_file.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:google_fonts/google_fonts.dart';

class CodeView extends ConsumerWidget {
  final String projectId;
  const CodeView({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        FileTreePanel(projectId: projectId),
        const VerticalDivider(width: 1, color: Colors.white24),
        Expanded(
          child: Column(
            children: [
              FileTabBar(),
              const Divider(height: 1, color: Colors.white24),
              const Expanded(
                child: CodeEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FileTreePanel extends ConsumerWidget {
  final String projectId;
  const FileTreePanel({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesState = ref.watch(projectFilesProvider(projectId));

    return Container(
      width: 250,
      color: Colors.black.withOpacity(0.2),
      child: filesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filesState.error != null
              ? Center(child: Text(filesState.error!))
              : ListView.builder(
                  itemCount: filesState.files.length,
                  itemBuilder: (context, index) {
                    final file = filesState.files[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined,
                          size: 18, color: Colors.white70),
                      title: Text(
                        file.fileName,
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      onTap: () {
                        ref.read(codeViewProvider.notifier).openFile(file);
                      },
                    );
                  },
                ),
    );
  }
}

class FileTabBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeViewState = ref.watch(codeViewProvider);
    final openFiles = codeViewState.openFiles;
    final activeIndex = codeViewState.activeFileIndex;

    if (openFiles.isEmpty) {
      return Container(
        height: 40,
        color: Colors.grey.shade900,
        child: Center(
          child: Text(
            'Select a file to open',
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      color: Colors.grey.shade900,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: openFiles.length,
        itemBuilder: (context, index) {
          final file = openFiles[index];
          final isActive = index == activeIndex;
          return GestureDetector(
            onTap: () =>
                ref.read(codeViewProvider.notifier).setActiveFile(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive ? Colors.black : Colors.transparent,
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    file.fileName,
                    style: GoogleFonts.poppins(
                        color: isActive ? Colors.white : Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () =>
                        ref.read(codeViewProvider.notifier).closeFile(index),
                    child: const Icon(Icons.close, size: 16, color: Colors.white70),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CodeEditor extends ConsumerWidget {
  const CodeEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeViewState = ref.watch(codeViewProvider);
    final openFiles = codeViewState.openFiles;
    final activeIndex = codeViewState.activeFileIndex;

    if (activeIndex == -1 || openFiles.isEmpty) {
      return Center(
        child: Text(
          'No file selected',
          style: GoogleFonts.poppins(color: Colors.white54),
        ),
      );
    }

    final activeFile = openFiles[activeIndex];

    return SingleChildScrollView(
      child: HighlightView(
        activeFile.content,
        language: activeFile.fileType,
        theme: githubTheme,
        padding: const EdgeInsets.all(12),
        textStyle: GoogleFonts.firaCode(fontSize: 14),
      ),
    );
  }
}
