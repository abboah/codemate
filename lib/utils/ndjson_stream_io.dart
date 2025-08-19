import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NdjsonClient {
  final Uri url;
  final Map<String, String> headers;
  final String body;

  NdjsonClient({required this.url, required this.headers, required this.body});

  // Streams decoded JSON maps as they arrive.
  Stream<Map<String, dynamic>> stream() async* {
    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = body;
    final response = await request.send();
    if (response.statusCode != 200) {
      final errText = await response.stream.bytesToString();
      throw Exception('Streaming backend failed: $errText');
    }
    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map<Map<String, dynamic>>((line) => jsonDecode(line) as Map<String, dynamic>);
  }
}
