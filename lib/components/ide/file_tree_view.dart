import 'package:codemate/models/project_file.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/providers/diff_overlay_provider.dart';

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

  void _ensureExpandedForActive(ProjectFile? activeFile) {
    if (activeFile == null) return;
    final path = activeFile.path;
    final parts = path.split('/');
    if (parts.length <= 1) return;
    final ancestors = <String>[];
    for (int i = 1; i < parts.length; i++) {
      final dir = parts.sublist(0, i).join('/');
      ancestors.add(dir);
    }
    bool changed = false;
    for (final a in ancestors) {
      if (!_expandedNodes.contains(a)) {
        _expandedNodes.add(a);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final projectFilesState = ref.watch(projectFilesProvider(widget.projectId));
    final activeFile = ref.watch(codeViewProvider).activeFile;

    // Auto-expand to reveal active file
    _ensureExpandedForActive(activeFile);

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
              final root = _buildTree(filtered);
              final widgets = _buildDirWidgets(root, activeFile, isRoot: true);
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: widgets,
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

  _DirNode _buildTree(List<ProjectFile> files) {
    final _DirNode root = _DirNode(name: 'root', fullPath: '/');
    for (final file in files) {
      final parts = file.path.split('/');
      _DirNode current = root;
      for (int i = 0; i < parts.length - 1; i++) {
        final part = parts[i];
        final nextPath = current.fullPath == '/' ? part : '${current.fullPath}/$part';
        current = current.children.putIfAbsent(part, () => _DirNode(name: part, fullPath: nextPath));
      }
      current.files.add(file);
    }
    return root;
  }

  List<Widget> _buildDirWidgets(_DirNode node, ProjectFile? activeFile, {bool isRoot = false, double indent = 0}) {
    final List<Widget> widgets = [];

    // For root, render only its top-level directories and files
    final directories = node.children.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final files = node.files.toList()..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    if (!isRoot) {
      final isExpanded = _expandedNodes.contains(node.fullPath);
      widgets.add(
        _FolderItem(
          name: node.name,
          isExpanded: isExpanded,
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedNodes.remove(node.fullPath);
            } else {
              _expandedNodes.add(node.fullPath);
            }
          }),
          children: isExpanded
              ? [
                  // Nested directories
                  ...directories.expand((child) => _buildDirWidgets(child, activeFile, indent: indent + 16)),
                  // Files directly under this directory
                  ...files.map((file) => _FileItem(
                        file: file,
                        isActive: activeFile?.id == file.id,
                        onTap: () {
                          ref.read(diffOverlayProvider).clear();
                          ref.read(codeViewProvider.notifier).openFile(file);
                        },
                      )),
                ]
              : [],
          indent: indent,
        ),
      );
    } else {
      // Root level: render top-level directories and files
      for (final dir in directories) {
        widgets.addAll(_buildDirWidgets(dir, activeFile, indent: 0));
      }
      for (final file in files) {
        widgets.add(_FileItem(
          file: file,
          isActive: activeFile?.id == file.id,
          onTap: () {
            ref.read(diffOverlayProvider).clear();
            ref.read(codeViewProvider.notifier).openFile(file);
          },
        ));
      }
    }

    return widgets;
  }
}

class _DirNode {
  final String name;
  final String fullPath;
  final Map<String, _DirNode> children = {};
  final List<ProjectFile> files = [];

  _DirNode({required this.name, required this.fullPath});
}

class _FolderItem extends StatelessWidget {
  final String name;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Widget> children;
  final double indent;

  const _FolderItem({
    required this.name,
    required this.isExpanded,
    required this.onTap,
    required this.children,
    this.indent = 0,
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
            padding: EdgeInsets.only(left: indent + 8, right: 8, top: 6, bottom: 6),
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
            padding: EdgeInsets.only(left: indent + 16),
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
