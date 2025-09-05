import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

class InlineCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Text(
      '`${element.textContent}`',
      style: GoogleFonts.firaCode(
        color: Colors.amber[200],
        backgroundColor: Colors.white.withOpacity(0.15),
        fontSize: 14,
      ),
    );
  }
}
