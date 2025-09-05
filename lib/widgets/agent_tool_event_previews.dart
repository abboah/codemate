import 'package:flutter/material.dart';
import 'package:codemate/widgets/tool_event_previews.dart';

/// Lightweight wrapper for ToolEventPreviews tailored for Agent chat.
///
/// It reuses the existing playground previews (project card, todo list, artifact read),
/// and supplies no-op handlers for canvas-related hooks which aren't used by Agent.
class AgentToolEventPreviews extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const AgentToolEventPreviews({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return ToolEventPreviews(
      events: events,
      fetchCanvasPreview: (_) async => null,
      openCanvas: (_) {},
    );
  }
}
