import 'package:markdown/markdown.dart' as md;

// A custom inline syntax for recognizing [codemate-diff-preview path/to/file]
class DiffPreviewSyntax extends md.InlineSyntax {
  DiffPreviewSyntax() : super(r'\[codemate-diff-preview\s+([^\]]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final path = match.group(1)!;
    md.Element el = md.Element.text('diff-preview', path);
    parser.addNode(el);
    return true;
  }
}
