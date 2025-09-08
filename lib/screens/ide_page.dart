import 'dart:ui';

import 'package:codemate/components/ide/agent_chat_view.dart';
import 'package:codemate/components/ide/code_editor_view.dart';
import 'package:codemate/components/ide/file_tree_view.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:codemate/components/ide/terminal_view.dart';
import 'package:codemate/themes/colors.dart';
import 'package:codemate/widgets/fancy_loader.dart';
import 'package:codemate/components/ide/live_preview_ide_view.dart';

class IdePage extends ConsumerStatefulWidget {
  final String projectId;
  const IdePage({super.key, required this.projectId});

  @override
  ConsumerState<IdePage> createState() => _IdePageState();
}

class _IdePageState extends ConsumerState<IdePage> {
  final MultiSplitViewController _horizontalController = MultiSplitViewController(
    areas: [
      Area(flex: 2, min: 200), // File Tree ~20%
      Area(flex: 5, min: 420), // Editor ~50%
      Area(flex: 3, min: 360), // Agent Chat ~30%
    ],
  );

  String? _projectName;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _loadProjectName();
  }

  Future<void> _loadProjectName() async {
    try {
      final res = await Supabase.instance.client
          .from('projects')
          .select('name')
          .eq('id', widget.projectId)
          .single();
      if (mounted) {
        setState(() => _projectName = (res['name'] as String?) ?? 'Project');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _projectName = 'Project');
      }
    }
  }

  Future<void> _editProjectName() async {
    final controller = TextEditingController(text: _projectName ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121214),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Icon(Icons.drive_file_rename_outline, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text('Rename Project', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Give your project a memorable name.', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter new project name',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == _projectName) return;

    setState(() => _isSavingName = true);
    try {
      await Supabase.instance.client
          .from('projects')
          .update({'name': newName})
          .eq('id', widget.projectId);
      setState(() => _projectName = newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to rename project: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  void _openTerminalModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Terminal',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Center(child: TerminalView(projectId: widget.projectId)),
          ],
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Opacity(
          opacity: curved.value,
          child: Transform.scale(scale: 0.98 + 0.02 * curved.value, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 160),
    );
  }

  void _openLivePreviewModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Live Preview',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, a1, a2) {
        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
            Center(child: LivePreviewIdeView(projectId: widget.projectId)),
          ],
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Opacity(
          opacity: curved.value,
          child: Transform.scale(scale: 0.98 + 0.02 * curved.value, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 160),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        titleSpacing: 12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
                Icon(Icons.widgets_outlined, color: AppColors.accent.withOpacity(0.8)),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _projectName ?? 'Loading…',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Rename project',
                    child: InkWell(
                      onTap: _isSavingName ? null : _editProjectName,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: _isSavingName
                            ? const SizedBox(width: 16, height: 16, child: WaveLoader(size: 16))
                            : const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _openTerminalModal,
            icon: const Icon(Icons.terminal_outlined, size: 18),
            label: const Text('Terminal'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _openLivePreviewModal,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Live Preview'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 3,
          dividerPainter: DividerPainters.grooved1(
            color: const Color(0xFF0F0F0F),
                highlightedColor: AppColors.accent.withOpacity(0.4),
          ),
        ),
        child: MultiSplitView(
          controller: _horizontalController,
          builder: (context, area) {
            switch (area.index) {
              case 0:
                return _PaneContainer(
                  title: 'Explorer',
                  trailing: IconButton(
                    tooltip: 'Refresh Files',
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
                    onPressed: () => ref.invalidate(projectFilesProvider(widget.projectId)),
                  ),
                  child: FileTreeView(projectId: widget.projectId),
                );
              case 1:
                return const _PaneContainer(
                  title: 'Editor',
                  child: CodeEditorView(),
                );
              case 2:
                // The AgentChatView gets its own container without a title bar
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: AgentChatView(projectId: widget.projectId),
                  ),
                );
              default:
                return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}

class _PaneContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _PaneContainer({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
