// Stub implementation for non-web or Wasm builds.
import 'dart:async';
import 'dart:typed_data';

class WebContainerProcess {
  final Stream<String> stdout = const Stream.empty();
  final Stream<String> stderr = const Stream.empty();
  final Future<int> exitCode = Future.value(1);
}

class WebContainerService {
  bool get isBooted => false;

  Future<void> boot() async => _unsupported();
  Future<void> mount(Map<String, dynamic> tree) async => _unsupported();
  Future<void> writeFile(String path, Uint8List data) async => _unsupported();
  WebContainerProcess spawn(String cmd, List<String> args) => _unsupported();
  void onServerReady(void Function(int port, String url) cb) => _unsupported();

  Never _unsupported() {
    throw UnsupportedError(
      'WebContainers are only supported on Flutter Web with JS.',
    );
  }
}
