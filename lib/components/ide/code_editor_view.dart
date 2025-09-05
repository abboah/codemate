import 'dart:async';

import 'package:codemate/models/project_file.dart';
import 'package:codemate/providers/code_view_provider.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/themes/vs2015.dart'; // A nice dark theme
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/all.dart';
import 'package:codemate/components/ide/diff_preview.dart';
import 'package:codemate/providers/diff_overlay_provider.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/themes/colors.dart';

class CodeEditorView extends ConsumerStatefulWidget {
  const CodeEditorView({super.key});

  @override
  ConsumerState<CodeEditorView> createState() => _CodeEditorViewState();
}

class _CodeEditorViewState extends ConsumerState<CodeEditorView> {
  CodeController? _controller;
  Timer? _debounce;
  String? _boundFileId; // Track which file the controller is bound to
  bool _saving = false;
  DateTime? _lastSavedAt;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _bindControllerToFile(ProjectFile file, String initialCode) {
    final language = _getLanguageForPath(file.path);

    if (_controller == null) {
      _controller = CodeController(text: initialCode, language: language);
      _boundFileId = file.id;
      return;
    }

    if (_boundFileId != file.id) {
      _controller!
        ..language = language
        ..text = initialCode
        ..selection = const TextSelection.collapsed(offset: 0);
      _boundFileId = file.id;
    } else {
      _controller!.language = language;
      if (_controller!.text != initialCode) {
        _controller!
          ..text = initialCode
          ..selection = const TextSelection.collapsed(offset: 0);
      }
    }
  }

  Mode? _getLanguageForPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    // Explicit mapping for common languages to ensure accuracy
    const languageMap = {
      'js': 'javascript',
      'jsx': 'javascript',
      'ts': 'typescript',
      'tsx': 'typescript',
      'py': 'python',
      'java': 'java',
      'html': 'xml', // HTML is a form of XML for highlighting
      'css': 'css',
      'json': 'json',
      'md': 'markdown',
      'yaml': 'yaml',
      'yml': 'yaml',
      'dart': 'dart',
      'c': 'c',
      'cpp': 'cpp',
      'cs': 'cs',
      'go': 'go',
      'php': 'php',
      'rb': 'ruby',
      'rs': 'rust',
      'sh': 'shell',
      'sql': 'sql',
    };
    final langName = languageMap[extension];
    return allLanguages[langName ?? extension];
  }

  void _scheduleAutosave(ProjectFile file, String newText) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      setState(() => _saving = true);
      try {
        await ref.read(projectFilesProvider(file.projectId).notifier).updateFileContent(file.id, newText);
        setState(() => _lastSavedAt = DateTime.now());
      } catch (_) {
        // Errors are handled in provider
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final codeView = ref.watch(codeViewProvider);
    final codeViewController = ref.read(codeViewProvider.notifier);

    final openFiles = codeView.openFiles;
    final activeFile = codeView.activeFile;
    if (activeFile == null) {
      return Center(
        child: Text(
          'Select a file to begin editing.',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white54),
        ),
      );
    }

    _bindControllerToFile(activeFile, codeView.code);

    final overlay = ref.watch(diffOverlayProvider);
    final showOverlay = overlay.path == activeFile.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs bar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in openFiles)
                        _TabChip(
                          file: f,
                          active: f.id == activeFile.id,
                          onSelect: () => codeViewController.switchTab(f.id),
                          onClose: () => codeViewController.closeTab(f.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_saving) ...[
                const SizedBox(width: 14, height: 14, child: MiniWave(size: 14)),
                const SizedBox(width: 6),
                Text('Saving…', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ] else if (_lastSavedAt != null) ...[
                const Icon(Icons.check, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text('Saved', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ],
            ],
          ),
        ),
        // Editor body or Diff overlay
        if (showOverlay)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: DiffPreview(
                path: activeFile.path,
                oldContent: overlay.oldContent,
                newContent: overlay.newContent,
                collapsible: false,
                scrollable: true,
              ),
            ),
          )
        else
          Expanded(
            child: CodeTheme(
              data: CodeThemeData(styles: vs2015Theme),
              child: CodeField(
                key: ValueKey(_boundFileId),
                controller: _controller!,
                expands: true,
                textStyle: GoogleFonts.robotoMono(fontSize: 14, height: 1.5),
                onChanged: (value) {
                  codeViewController.updateCode(value);
                  _scheduleAutosave(activeFile, value);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final ProjectFile file;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  const _TabChip({
    required this.file,
    required this.active,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.white.withOpacity(0.10) : Colors.transparent;
    final fg = active ? Colors.white : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Tooltip(
        message: file.path,
        waitDuration: const Duration(milliseconds: 1000),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        textStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 14, color: fg),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    file.path.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: fg, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClose,
                  child: Icon(Icons.close_rounded, size: 14, color: fg.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
