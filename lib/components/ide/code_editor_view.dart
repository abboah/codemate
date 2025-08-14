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
        ..text = initialCode;
      _boundFileId = file.id;
    } else {
      _controller!.language = language;
      if (_controller!.text != initialCode) {
        _controller!.text = initialCode;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editor header: path and save status
        Container(
          height: 36,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeFile.path,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
                ),
              ),
              if (_saving) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                const SizedBox(width: 6),
                Text('Saving…', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ] else if (_lastSavedAt != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text('Saved', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ]
            ],
          ),
        ),
        // Editor body
        Expanded(
          child: CodeTheme(
            data: CodeThemeData(styles: vs2015Theme),
            child: CodeField(
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
