import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TemplatePrompt {
  final String face;
  final String actual;
  const TemplatePrompt({required this.face, required this.actual});
}

class TemplatePromptPills extends StatelessWidget {
  final List<TemplatePrompt> templates;
  final void Function(TemplatePrompt t) onSelect;
  final EdgeInsetsGeometry padding;
  const TemplatePromptPills({
    super.key,
    required this.templates,
    required this.onSelect,
    this.padding = const EdgeInsets.only(top: 8),
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            templates
                .map((t) => _Pill(face: t.face, onTap: () => onSelect(t)))
                .toList(),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String face;
  final VoidCallback onTap;
  const _Pill({required this.face, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.purpleAccent, size: 14),
            const SizedBox(width: 8),
            Text(
              face,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
