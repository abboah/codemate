import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({List<String> mentionPaths = const []}) : _mentionPaths = List.from(mentionPaths);

  List<String> _mentionPaths;

  void setMentionPaths(List<String> paths) {
    _mentionPaths = List.from(paths);
    // Force rebuild of text layout
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final baseStyle = style ?? const TextStyle();
    final textValue = text;

    if (_mentionPaths.isEmpty || textValue.isEmpty) {
      return TextSpan(style: baseStyle, text: textValue);
    }

    final children = <InlineSpan>[];
    int index = 0;

    // Build a list of all mention occurrences in the text
    final matches = <_MentionMatch>[];
    for (final path in _mentionPaths) {
      final needle = '@' + path;
      int start = 0;
      while (true) {
        final found = textValue.indexOf(needle, start);
        if (found == -1) break;
        matches.add(_MentionMatch(start: found, end: found + needle.length, text: needle));
        start = found + needle.length;
      }
    }

    if (matches.isEmpty) {
      return TextSpan(style: baseStyle, text: textValue);
    }

    // Sort by start index to lay out sequentially
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final m in matches) {
      if (m.start > index) {
        children.add(TextSpan(style: baseStyle, text: textValue.substring(index, m.start)));
      }
      // Mention style: inline code-like
      children.add(TextSpan(
        text: m.text,
        style: GoogleFonts.robotoMono(
          color: Colors.white.withOpacity(0.95),
          backgroundColor: Colors.black.withOpacity(0.35),
          fontSize: baseStyle.fontSize ?? 14,
        ),
      ));
      index = m.end;
    }

    if (index < textValue.length) {
      children.add(TextSpan(style: baseStyle, text: textValue.substring(index)));
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

class _MentionMatch {
  final int start;
  final int end;
  final String text;
  _MentionMatch({required this.start, required this.end, required this.text});
} 