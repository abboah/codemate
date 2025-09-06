// Web implementation: render HTML/CSS/JS using a sandboxed iframe via HtmlElementView
import 'dart:html' as html; // Only available on web
// Flutter web-only platform view registry API
import 'dart:ui_web' as ui; // For platformViewRegistry

import 'package:flutter/material.dart';

class CanvasHtmlPreview extends StatefulWidget {
  final String
  content; // HTML with optional inline CSS/JS; non-HTML wrapped heuristically
  const CanvasHtmlPreview({super.key, required this.content});

  @override
  State<CanvasHtmlPreview> createState() => _CanvasHtmlPreviewState();
}

class _CanvasHtmlPreviewState extends State<CanvasHtmlPreview> {
  late String _viewTypeId;
  html.IFrameElement? _iframe;
  bool _suspended = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register for global suspend/resume notifications
    CanvasHtmlOverlayController.instance.addListener(_onSuspendChanged);
  }

  @override
  void dispose() {
    CanvasHtmlOverlayController.instance.removeListener(_onSuspendChanged);
    super.dispose();
  }

  void _onSuspendChanged(bool value) {
    if (!mounted) return;
    setState(() => _suspended = value);
  }

  @override
  void initState() {
    super.initState();
    _registerView(widget.content);
  }

  void _registerView(String content) {
    _viewTypeId =
        'canvas-html-preview-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    // Register a factory that creates the iframe; capture reference for updates
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewTypeId, (int viewId) {
      final iframe =
          html.IFrameElement()
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '100%'
            // Allow scripts and same-origin so localStorage and cookies APIs work
            ..sandbox?.add('allow-scripts')
            ..sandbox?.add('allow-same-origin')
            // Allow pointer lock for mouse capture (useful for web apps with mouse navigation)
            ..sandbox?.add('allow-pointer-lock')
            // Make the iframe focusable and request focus on click so mouse/keyboard events go inside
            ..tabIndex = 0
            // Use srcdoc to guarantee same-origin about:srcdoc document, enabling localStorage
            ..srcdoc = _wrapIfNeeded(content);
      // Focus on click for better input/gesture handling inside the app
      iframe.onClick.listen((_) {
        iframe.focus();
        try {
          // Attempt to request pointer lock; ignore failures
          (iframe.contentWindow as dynamic)
              .document
              ?.documentElement
              ?.requestPointerLock
              ?.call();
        } catch (_) {}
      });
      _iframe = iframe;
      return iframe;
    });
  }

  String _wrapIfNeeded(String content) {
    final lower = content.toLowerCase();
    final looksHtml = lower.contains('<html') || lower.contains('<!doctype');
    if (looksHtml) return content;
    final hasScriptTag = lower.contains('<script');
    final hasStyleTag = lower.contains('<style');
    final hasTags = lower.contains('<');
    final maybeJs =
        content.contains('function ') ||
        content.contains('const ') ||
        content.contains('let ') ||
        content.contains('=>');
    final maybeCss =
        !maybeJs &&
        (content.contains('{') &&
            content.contains('}') &&
            content.contains(';'));
    final bodyInner = StringBuffer();
    if (hasScriptTag || hasStyleTag || hasTags) {
      bodyInner.write(content);
    } else if (maybeJs) {
      bodyInner.write('<script>\n');
      bodyInner.write(content);
      bodyInner.write('\n<\/script>');
    } else if (maybeCss) {
      bodyInner.write('<style>\n');
      bodyInner.write(content);
      bodyInner.write('\n<\/style>');
      bodyInner.write(
        '<div class="note">CSS loaded. Add HTML to see styled elements.</div>',
      );
    } else {
      bodyInner.write('<pre>');
      bodyInner.write(_escapeHtml(content));
      bodyInner.write('</pre>');
    }
    return '<!doctype html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>html,body{margin:0;padding:16px;background:#0b0f19;color:#eaeaea;font-family:Inter,system-ui,-apple-system,Segoe UI,Roboto} .note{opacity:.7;font-style:italic;margin-top:8px}</style>'
        '</head><body>'
        '${bodyInner.toString()}'
        '</body></html>';
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  @override
  void didUpdateWidget(covariant CanvasHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      if (_iframe != null) {
        _iframe!.srcdoc = _wrapIfNeeded(widget.content);
      } else {
        // If iframe not created yet, re-register a new view type to ensure update
        _registerView(widget.content);
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewTypeId),
        if (_suspended)
          IgnorePointer(
            ignoring: true,
            child: Container(color: Colors.transparent),
          ),
      ],
    );
  }
}

class CanvasHtmlOverlayController {
  CanvasHtmlOverlayController._();
  static final CanvasHtmlOverlayController instance = CanvasHtmlOverlayController._();

  final List<void Function(bool)> _listeners = [];
  void addListener(void Function(bool) fn) { if (!_listeners.contains(fn)) _listeners.add(fn); }
  void removeListener(void Function(bool) fn) { _listeners.remove(fn); }
  void suspend() { for (final l in List.of(_listeners)) { try { l(true); } catch (_) {} } }
  void resume() { for (final l in List.of(_listeners)) { try { l(false); } catch (_) {} } }
}
