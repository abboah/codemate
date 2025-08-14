import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DiffPreview extends StatefulWidget {
  final String path;
  final String oldContent;
  final String newContent;
  final int maxLines;

  const DiffPreview({
    super.key,
    required this.path,
    required this.oldContent,
    required this.newContent,
    this.maxLines = 100, // Increased max lines
  });

  @override
  State<DiffPreview> createState() => _DiffPreviewState();
}

class _DiffPreviewState extends State<DiffPreview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lines = _buildUnifiedDiff(widget.oldContent, widget.newContent);
    final visibleLines = _expanded ? lines : lines.take(15).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black.withOpacity(0.25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(Icons.compare_arrows_rounded, size: 18, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.path,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code lines
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DefaultTextStyle(
              style: GoogleFonts.robotoMono(fontSize: 13, height: 1.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visibleLines.map((l) => _buildLine(context, l)).toList(),
              ),
            ),
          ),
          // Expander
          if (lines.length > 15)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded ? 'Show less' : 'Show ${lines.length - 15} more lines...',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLine(BuildContext context, _DiffLine line) {
    Color? barColor;
    Color? bgColor;
    String prefix;

    switch (line.kind) {
      case _DiffKind.add:
        barColor = Colors.green.shade400;
        bgColor = Colors.green.withOpacity(0.1);
        prefix = '+';
        break;
      case _DiffKind.remove:
        barColor = Colors.red.shade400;
        bgColor = Colors.red.withOpacity(0.1);
        prefix = '-';
        break;
      case _DiffKind.context:
      default:
        barColor = Colors.grey.withOpacity(0.2);
        bgColor = Colors.transparent;
        prefix = ' ';
        break;
    }

    return Container(
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 19.5, color: barColor), // Bar
          const SizedBox(width: 8),
          Text(prefix, style: TextStyle(color: Colors.white.withOpacity(0.5))),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: _buildHighlightedText(line.text),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildHighlightedText(String text) {
    final spans = <TextSpan>[];
    final keywordColor = Colors.blue.shade300;
    final stringColor = Colors.orange.shade300;
    final numberColor = Colors.purple.shade200;
    final commentColor = Colors.green.shade300;
    final defaultColor = Colors.white.withOpacity(0.85);

    const keywords = {'var', 'final', 'const', 'String', 'int', 'double', 'bool', 'if', 'else', 'for', 'while', 'return', 'class', 'extends', 'with', 'void', 'new', 'await', 'async', 'import', 'export', 'part', 'package'};

    final String pattern = [
      r'(\b(?:' + keywords.join('|') + r')\b)', // Keywords
      r'(".*?"|".*?")', // Strings
      r'(\b\d+\.?\d*\b)', // Numbers
      r'(//.*)', // Comments
    ].join('|');

    final RegExp exp = RegExp(pattern);

    text.splitMapJoin(
      exp,
      onMatch: (Match m) {
        if (m[1] != null) {
          spans.add(TextSpan(text: m[1], style: TextStyle(color: keywordColor, fontWeight: FontWeight.bold)));
        } else if (m[2] != null) {
          spans.add(TextSpan(text: m[2], style: TextStyle(color: stringColor)));
        } else if (m[3] != null) {
          spans.add(TextSpan(text: m[3], style: TextStyle(color: numberColor)));
        } else if (m[4] != null) {
          spans.add(TextSpan(text: m[4], style: TextStyle(color: commentColor, fontStyle: FontStyle.italic)));
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: TextStyle(color: defaultColor)));
        return '';
      },
    );

    return TextSpan(children: spans);
  }

  List<_DiffLine> _buildUnifiedDiff(String oldStr, String newStr) {
    final a = oldStr.split('\n');
    final b = newStr.split('\n');
    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (int i = m - 1; i >= 0; i--) {
      for (int j = n - 1; j >= 0; j--) {
        if (a[i] == b[j]) {
          dp[i][j] = dp[i + 1][j + 1] + 1;
        } else {
          dp[i][j] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }
    int i = 0, j = 0;
    final lines = <_DiffLine>[];
    while (i < m && j < n) {
      if (a[i] == b[j]) {
        lines.add(_DiffLine(_DiffKind.context, a[i]));
        i++; j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        lines.add(_DiffLine(_DiffKind.remove, a[i]));
        i++;
      } else {
        lines.add(_DiffLine(_DiffKind.add, b[j]));
        j++;
      }
    }
    while (i < m) { lines.add(_DiffLine(_DiffKind.remove, a[i++])); }
    while (j < n) { lines.add(_DiffLine(_DiffKind.add, b[j++])); }
    return lines;
  }
}

enum _DiffKind { add, remove, context }

class _DiffLine {
  final _DiffKind kind;
  final String text;
  _DiffLine(this.kind, this.text);
}