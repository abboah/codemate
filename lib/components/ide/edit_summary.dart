import 'package:flutter/material.dart';

class EditsSummary extends StatelessWidget {
  final List<dynamic> fileEdits;
  const EditsSummary({super.key, required this.fileEdits});

  @override
  Widget build(BuildContext context) {
    if (fileEdits.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final creates = fileEdits.where((e) => (e['operation'] as String?) == 'create').toList();
    final updates = fileEdits.where((e) => (e['operation'] as String?) == 'update').toList();
    final deletes = fileEdits.where((e) => (e['operation'] as String?) == 'delete').toList();
    final reads = fileEdits.where((e) => (e['operation'] as String?) == 'read').toList();
    final totalChanges = creates.length + updates.length + deletes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.change_circle_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              totalChanges == 1 ? '1 change' : '${totalChanges} changes',
              style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
            if (reads.isNotEmpty) ...[
              const SizedBox(width: 10),
              Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                reads.length == 1 ? '1 read' : '${reads.length} reads',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...creates.map((e) => _opChip(context, e, 'Created', Icons.add_circle_outline, Colors.green)),
            ...updates.map((e) => _opChip(context, e, 'Updated', Icons.edit_outlined, Colors.blue)),
            ...deletes.map((e) => _opChip(context, e, 'Deleted', Icons.delete_outline, Colors.red)),
            ...reads.map((e) => _opChip(context, e, 'Read', Icons.visibility_outlined, Colors.orange)),
          ],
        ),
      ],
    );
  }

  Widget _opChip(BuildContext context, dynamic e, String label, IconData icon, Color color) {
    final path = (e['path'] as String?) ?? 'unknown';
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
          const SizedBox(width: 6),
          Text(path, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.75))),
        ],
      ),
    );
  }
} 