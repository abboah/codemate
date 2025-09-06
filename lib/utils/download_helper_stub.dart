// Fallback (non-web) implementation using dart:io to write a file to the user's Downloads directory when possible.
// If the path is not available (e.g., sandboxed), we write to the temporary directory.
import 'dart:io';

class DownloadHelper {
  static Future<bool> saveTextFile({
    required String filename,
    required String mime,
    required String content,
  }) async {
    try {
      // Try common downloads directories
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      final candidates = <String>[
        if (home != null) '$home/Downloads',
        Directory.current.path,
        Directory.systemTemp.path,
      ];
      for (final dir in candidates) {
        try {
          final d = Directory(dir);
          if (await d.exists()) {
            final file = File('${d.path}/$filename');
            await file.writeAsString(content);
            return true;
          }
        } catch (_) {
          // continue
        }
      }
      // Last resort: write to temp
      final file = File('${Directory.systemTemp.path}/$filename');
      await file.writeAsString(content);
      return true;
    } catch (_) {
      return false;
    }
  }
}
