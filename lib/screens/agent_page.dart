import 'package:codemate/chatbot/chat_history_panel.dart';
import 'package:codemate/components/agent/agent_view.dart';
import 'package:codemate/components/agent/code_view.dart';
import 'package:codemate/providers/active_chat_provider.dart';
import 'package:codemate/providers/agent_provider.dart';
import 'package:codemate/providers/chat_history_provider.dart';
import 'package:codemate/providers/projects_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentPage extends ConsumerWidget {
  final String projectId;
  const AgentPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAgentView = ref.watch(agentViewProvider);
    final project = ref.watch(projectsProvider).getProjectById(projectId);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    if (project == null) {
      return const Scaffold(
        body: Center(child: Text('Project not found.')),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.black,
      appBar: AppBar(
        titleSpacing: 16.0,
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            _EditableProjectTitle(
              projectId: projectId,
              initialTitle: project.name,
            ),
            const Spacer(),
            _ViewToggle(
              isAgentView: isAgentView,
              onToggle: (value) {
                ref.read(agentViewProvider.notifier).state = value;
              },
            ),
            const Spacer(),
          ],
        ),
        actions: [
          Tooltip(
            message: 'New Chat',
            child: IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () async {
                final newChatId = await ref
                    .read(chatHistoryProvider(projectId).notifier)
                    .createChat(projectId);
                ref.read(activeChatProvider.notifier).state = newChatId;
              },
            ),
          ),
          Tooltip(
            message: 'Chat History',
            child: IconButton(
              icon: const Icon(Icons.history_outlined),
              onPressed: () {
                scaffoldKey.currentState?.openEndDrawer();
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: Drawer(
        child: ChatHistoryPanel(projectId: projectId),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isAgentView
            ? AgentView(key: const ValueKey('AgentView'), project: project)
            : CodeView(key: const ValueKey('CodeView'), projectId: projectId),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool isAgentView;
  final Function(bool) onToggle;

  const _ViewToggle({required this.isAgentView, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: true,
          label: Text('Agent'),
          icon: Icon(Icons.chat_bubble_outline, size: 18),
        ),
        ButtonSegment<bool>(
          value: false,
          label: Text('Code'),
          icon: Icon(Icons.code, size: 18),
        ),
      ],
      selected: {isAgentView},
      onSelectionChanged: (newSelection) {
        onToggle(newSelection.first);
      },
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        selectedForegroundColor: Colors.white,
        selectedBackgroundColor: Colors.blueAccent,
      ),
    );
  }
}

class _EditableProjectTitle extends ConsumerStatefulWidget {
  final String projectId;
  final String initialTitle;

  const _EditableProjectTitle(
      {required this.projectId, required this.initialTitle});

  @override
  ConsumerState<_EditableProjectTitle> createState() =>
      __EditableProjectTitleState();
}

class __EditableProjectTitleState extends ConsumerState<_EditableProjectTitle> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveTitle();
    }
  }

  Future<void> _saveTitle() async {
    setState(() {
      _isEditing = false;
    });
    if (_controller.text.isNotEmpty &&
        _controller.text != widget.initialTitle) {
      try {
        await Supabase.instance.client
            .from('projects')
            .update({'name': _controller.text}).eq('id', widget.projectId);
        // Refresh projects list silently
        ref.read(projectsProvider).fetchProjects();
      } catch (e) {
        // Revert on error
        _controller.text = widget.initialTitle;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving title: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditing = true;
        });
        _focusNode.requestFocus();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        child: _isEditing
            ? TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: InputBorder.none,
                ),
                onFieldSubmitted: (_) => _saveTitle(),
              )
            : Text(
                _controller.text,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500),
              ),
      ),
    );
  }
}