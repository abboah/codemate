import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class NdjsonClient {
  final Uri url;
  final Map<String, String> headers;
  final String body;

  NdjsonClient({required this.url, required this.headers, required this.body});

  // Uses XMLHttpRequest to receive progressive responseText and split into lines.
  Stream<Map<String, dynamic>> stream() {
    final controller = StreamController<Map<String, dynamic>>();
    final xhr = html.HttpRequest();

    // Set headers
    xhr.open('POST', url.toString(), async: true);
    headers.forEach((k, v) {
      try { xhr.setRequestHeader(k, v); } catch (_) {}
    });

  var lastIndex = 0;
  var buffer = '';

    xhr.onProgress.listen((_) {
      final text = xhr.responseText ?? '';
      // Process new chunk from lastIndex
      final newChunk = text.substring(lastIndex);
      lastIndex = text.length;
      buffer += newChunk;
      final parts = buffer.split('\n');
      // Keep last piece in buffer if not newline-terminated
      buffer = parts.removeLast();
      for (final line in parts) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final obj = jsonDecode(trimmed) as Map<String, dynamic>;
          controller.add(obj);
        } catch (_) {}
      }
    });

    xhr.onLoad.listen((_) {
      // Flush any remaining data
      final text = xhr.responseText ?? '';
      if (lastIndex < text.length) {
        buffer += text.substring(lastIndex);
      }
      if (buffer.isNotEmpty) {
        for (final line in const LineSplitter().convert(buffer)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final obj = jsonDecode(trimmed) as Map<String, dynamic>;
            controller.add(obj);
          } catch (_) {}
        }
      }
      controller.close();
    });

    xhr.onError.listen((_) {
      controller.addError(Exception('Network error while streaming NDJSON'));
      controller.close();
    });

    xhr.send(body);

    return controller.stream;
  }
}
