import 'package:codemate/models/project_file.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class FileTreeView extends ConsumerStatefulWidget {
  final String projectId;
  const FileTreeView({super.key, required this.projectId});

  @override
  ConsumerState<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends ConsumerState<FileTreeView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _expandedNodes = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectFilesState = ref.watch(projectFilesProvider(widget.projectId));
    final activeFile = ref.watch(codeViewProvider).activeFile;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Search files…',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (projectFilesState.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }
              if (projectFilesState.error != null) {
                return Center(child: Text('Error: ${projectFilesState.error}', style: const TextStyle(color: Colors.redAccent)));
              }
              if (projectFilesState.files.isEmpty) {
                return Center(
                  child: Text(
                    'No files in this project yet.',
                    style: GoogleFonts.poppins(color: Colors.white54),
                  ),
                );
              }

              final filtered = _filterFiles(projectFilesState.files, _query);
              final fileTree = _buildFileTree(filtered, activeFile);
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: fileTree,
              );
            },
          ),
        ),
      ],
    );
  }

  List<ProjectFile> _filterFiles(List<ProjectFile> files, String query) {
    if (query.isEmpty) return files;
    return files.where((f) => f.path.toLowerCase().contains(query)).toList();
  }

  List<Widget> _buildFileTree(List<ProjectFile> files, ProjectFile? activeFile) {
    final Map<String, List<dynamic>> tree = {};

    for (var file in files) {
      List<String> parts = file.path.split('/');
      Map<String, List<dynamic>> currentLevel = tree;
      for (int i = 0; i < parts.length - 1; i++) {
        String part = parts[i];
        currentLevel.putIfAbsent(part, () => <dynamic>[]);
        currentLevel = { for (var k in currentLevel.keys) k: currentLevel[k]! }; // This is a bit of a hack
        var nextLevel = currentLevel[part];
        if (nextLevel is List) {
            // Find the map in the list or create it
            var found = false;
            for (var item in nextLevel) {
                if (item is Map<String, List<dynamic>> && item.containsKey(part)) {
                    currentLevel = item[part] as Map<String, List<dynamic>>;
                    found = true;
                    break;
                }
            }
            if (!found) {
                Map<String, List<dynamic>> newLevel = {};
                nextLevel.add(newLevel);
                currentLevel = newLevel;
            }
        }
      }
      final fileName = parts.last;
      tree.putIfAbsent(parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '/', () => []);
      (tree[parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '/'] as List).add(file);
    }

    // This is a simplified representation. A proper recursive function would be better.
    // For now, we will stick to the flat structure as the logic for deep nesting is complex.
    final Map<String, List<ProjectFile>> directoryMap = {};
    for (var file in files) {
      final parts = file.path.split('/');
      final directory = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '/';
      directoryMap.putIfAbsent(directory, () => []);
      directoryMap[directory]!.add(file);
    }
    final sortedDirectories = directoryMap.keys.toList()..sort();

    return sortedDirectories.map((directory) {
      final children = directoryMap[directory]!..sort((a, b) => a.path.compareTo(b.path));
      final isExpanded = _expandedNodes.contains(directory);

      return _FolderItem(
        name: directory,
        isExpanded: isExpanded,
        onTap: () => setState(() {
          if (isExpanded) {
            _expandedNodes.remove(directory);
          } else {
            _expandedNodes.add(directory);
          }
        }),
        children: isExpanded
            ? children.map((file) {
                return _FileItem(
                  file: file,
                  isActive: activeFile?.id == file.id,
                  onTap: () => ref.read(codeViewProvider.notifier).openFile(file),
                );
              }).toList()
            : [],
      );
    }).toList();
  }
}

class _FolderItem extends StatelessWidget {
  final String name;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Widget> children;

  const _FolderItem({
    required this.name,
    required this.isExpanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                  color: Colors.blueAccent.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name == '/' ? 'root' : name,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _FileItem extends StatefulWidget {
  final ProjectFile file;
  final bool isActive;
  final VoidCallback onTap;

  const _FileItem({
    required this.file,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_FileItem> createState() => _FileItemState();
}

class _FileItemState extends State<_FileItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForFile(widget.file.path);
    final color = widget.isActive ? Colors.blueAccent : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.blueAccent.withOpacity(0.2)
                : _isHovered
                    ? Colors.white.withOpacity(0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.file.path.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: widget.isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForFile(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'dart':
        return Icons.code_rounded;
      case 'ts':
      case 'tsx':
      case 'js':
      case 'jsx':
        return Icons.javascript_rounded;
      case 'md':
        return Icons.article_outlined;
      case 'yaml':
      case 'yml':
      case 'json':
        return Icons.data_object_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'svg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
