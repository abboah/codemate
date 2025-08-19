// Platform conditional import for NDJSON streaming
export 'ndjson_stream_io.dart'
  if (dart.library.html) 'ndjson_stream_web.dart';