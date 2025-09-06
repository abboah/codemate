// Web implementation for saving text content as a file using an anchor + Blob.
// Only compiled on web via conditional import.
import 'dart:html' as html;

class DownloadHelper {
  static Future<bool> saveTextFile({
    required String filename,
    required String mime,
    required String content,
  }) async {
    try {
      final bytes = html.Blob([content], mime);
      final url = html.Url.createObjectUrl(bytes);
      final anchor =
          html.AnchorElement(href: url)
            ..download = filename
            ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
