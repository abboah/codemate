import 'package:flutter/material.dart';

class CanvasHtmlPreview extends StatelessWidget {
  final String content;
  const CanvasHtmlPreview({super.key, required this.content});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('HTML preview is only available on Flutter web. Use WebView on mobile/desktop.'),
    );
  }
}
