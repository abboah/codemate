import 'package:codemate/components/ide/agent_chat_view.dart';
import 'package:codemate/components/ide/code_editor_view.dart';
import 'package:codemate/components/ide/file_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';

class IdePage extends StatefulWidget {
  final String projectId;
  const IdePage({super.key, required this.projectId});

  @override
  State<IdePage> createState() => _IdePageState();
}

class _IdePageState extends State<IdePage> {
  // Controller for the main horizontal split (File Tree | Editor | Chat)
  final MultiSplitViewController _horizontalController = MultiSplitViewController(
    areas: [
      Area(flex: 1, min: 180), // 10%
      Area(flex: 6, min: 400), // 60% - Added min size to prevent collapse
      Area(flex: 3, min: 350), // 30%
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project IDE'), // TODO: Replace with dynamic project name
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: const [], // Actions have been moved to AgentChatView
      ),
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 6,
          dividerPainter: DividerPainters.grooved1(
            color: theme.colorScheme.surface,
            highlightedColor: theme.colorScheme.primary.withOpacity(0.5),
          ),
        ),
        child: MultiSplitView(
          controller: _horizontalController,
          builder: (context, area) {
            switch (area.index) {
              case 0:
                return FileTreeView(projectId: widget.projectId);
              case 1:
                return const CodeEditorView(); // Directly show the editor
              case 2:
                return AgentChatView(projectId: widget.projectId);
              default:
                return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}