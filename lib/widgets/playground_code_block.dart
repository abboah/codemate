import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:google_fonts/google_fonts.dart';

class PlaygroundCodeBlock extends StatelessWidget {
  final String code;
  final String language;
  const PlaygroundCodeBlock({super.key, required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E14), // Darker than atomOne
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: HighlightView(
                      code,
                      language: language.isEmpty ? 'plaintext' : language,
                      theme: _playgroundTheme,
                      textStyle: GoogleFonts.jetBrainsMono(fontSize: 13.5, height: 1.55),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Tooltip(
                    message: 'Copy code',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_all_rounded, color: Color(0xFFB3C0D5), size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        messenger?.showSnackBar(const SnackBar(content: Text('Code copied')));
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom darker theme for Playground
const Map<String, TextStyle> _playgroundTheme = {
  'root': TextStyle(backgroundColor: Color(0xFF0B0E14), color: Color(0xFFB3C0D5)),
  'comment': TextStyle(color: Color(0xFF637777), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xFF637777), fontStyle: FontStyle.italic),
  'keyword': TextStyle(color: Color(0xFFD08770), fontWeight: FontWeight.w600),
  'selector-tag': TextStyle(color: Color(0xFFD08770)),
  'section': TextStyle(color: Color(0xFFE06C75)),
  'title': TextStyle(color: Color(0xFFA3BE8C)),
  'name': TextStyle(color: Color(0xFFE5C07B)),
  'literal': TextStyle(color: Color(0xFF56B6C2)),
  'string': TextStyle(color: Color(0xFF98C379)),
  'addition': TextStyle(color: Color(0xFF98C379)),
  'deletion': TextStyle(color: Color(0xFFE06C75)),
  'attribute': TextStyle(color: Color(0xFFE5C07B)),
  'built_in': TextStyle(color: Color(0xFFC678DD)),
  'type': TextStyle(color: Color(0xFF61AFEF)),
  'number': TextStyle(color: Color(0xFFD19A66)),
  'symbol': TextStyle(color: Color(0xFF61AFEF)),
  'bullet': TextStyle(color: Color(0xFF61AFEF)),
  'link': TextStyle(color: Color(0xFF61AFEF), decoration: TextDecoration.underline),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};
