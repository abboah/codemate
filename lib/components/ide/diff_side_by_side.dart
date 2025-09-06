import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum _DiffKind { add, remove, context }

class _PairLine {
  final String left;
  final String right;
  final _DiffKind leftKind;
  final _DiffKind rightKind;
  _PairLine({
    required this.left,
    required this.right,
    required this.leftKind,
    required this.rightKind,
  });
}

List<_PairLine> _buildSideBySidePairs(String oldStr, String newStr) {
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
  final pairs = <_PairLine>[];
  while (i < m && j < n) {
    if (a[i] == b[j]) {
      pairs.add(_PairLine(
        left: a[i],
        right: b[j],
        leftKind: _DiffKind.context,
        rightKind: _DiffKind.context,
      ));
      i++; j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      // remove from left
      pairs.add(_PairLine(
        left: a[i],
        right: '',
        leftKind: _DiffKind.remove,
        rightKind: _DiffKind.context,
      ));
      i++;
    } else {
      // add on right
      pairs.add(_PairLine(
        left: '',
        right: b[j],
        leftKind: _DiffKind.context,
        rightKind: _DiffKind.add,
      ));
      j++;
    }
  }
  while (i < m) {
    pairs.add(_PairLine(left: a[i++], right: '', leftKind: _DiffKind.remove, rightKind: _DiffKind.context));
  }
  while (j < n) {
    pairs.add(_PairLine(left: '', right: b[j++], leftKind: _DiffKind.context, rightKind: _DiffKind.add));
  }
  return pairs;
}

class SideBySideDiff extends StatelessWidget {
  final String path;
  final String oldContent;
  final String newContent;
  final bool showHeader;

  const SideBySideDiff({
    super.key,
    required this.path,
    required this.oldContent,
    required this.newContent,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final pairs = _buildSideBySidePairs(oldContent, newContent);
    final added = pairs.where((p) => p.rightKind == _DiffKind.add).length;
    final removed = pairs.where((p) => p.leftKind == _DiffKind.remove).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Icon(Icons.compare, size: 18, color: Colors.white.withOpacity(0.85)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "+$added",
                    style: GoogleFonts.jetBrainsMono(color: Colors.greenAccent.shade200, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "-$removed",
                    style: GoogleFonts.jetBrainsMono(color: Colors.redAccent.shade200, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              color: Colors.white.withOpacity(0.03),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Old', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                const SizedBox(width: 12),
                Expanded(child: Text('New', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  children: pairs.map((p) => _row(context, p)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _PairLine p) {
    Color? leftBg;
    Color? rightBg;
    Color leftBar = Colors.transparent;
    Color rightBar = Colors.transparent;

    if (p.leftKind == _DiffKind.remove) {
      leftBg = Colors.red.withOpacity(0.08);
      leftBar = Colors.red.shade400;
    }
    if (p.rightKind == _DiffKind.add) {
      rightBg = Colors.green.withOpacity(0.08);
      rightBar = Colors.green.shade400;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left
          Expanded(
            child: Container(
              color: leftBg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 3, height: 19.5, color: leftBar),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.left.isEmpty ? ' ' : p.left,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Right
          Expanded(
            child: Container(
              color: rightBg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 3, height: 19.5, color: rightBar),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.right.isEmpty ? ' ' : p.right,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
