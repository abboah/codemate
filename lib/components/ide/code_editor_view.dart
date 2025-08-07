import 'package:codemate/providers/code_view_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/all.dart';

class CodeEditorView extends ConsumerWidget {
  const CodeEditorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeView = ref.watch(codeViewProvider);
    final codeViewController = ref.read(codeViewProvider.notifier);

    if (codeView.activeFile == null) {
      return const Center(
        child: Text(
          'Select a file to view or edit its content.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final fileExtension = codeView.activeFile?.path.split('.').last;
    final controller = CodeController(
      text: codeView.code,
      language: allLanguages[fileExtension ?? ''] ?? allLanguages['plaintext'],
    );

    return CodeField(
      controller: controller,
      onChanged: (value) {
        codeViewController.updateCode(value);
      },
    );
  }
}