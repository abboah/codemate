import 'package:flutter/material.dart';

class CanvasHtmlPreview extends StatelessWidget {
  final String content;
  const CanvasHtmlPreview({super.key, required this.content});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'HTML preview is only available on Flutter web. Use WebView on mobile/desktop.',
      ),
    );
  }
}

// No-op overlay controller for non-web builds so callers can safely suspend/resume
class CanvasHtmlOverlayController {
  CanvasHtmlOverlayController._();
  static final CanvasHtmlOverlayController instance =
      CanvasHtmlOverlayController._();
  void addListener(void Function(bool) fn) {}
  void removeListener(void Function(bool) fn) {}
  void suspend() {}
  void resume() {}
}
