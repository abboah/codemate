// Web implementation using JS interop. Compiled only when dart.library.js is available.
import 'dart:async';
import 'dart:typed_data';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as jsu;

@JS('WebContainer.boot')
external Object _boot();

@JS()
@anonymous
class _JsWebContainerInstance {
  external Object get fs; // has writeFile/readFile/etc.
  external Object spawn(String cmd, List args, [Object? options]);
  external void on(String event, Function cb);
  external Object mount(Object tree);
}

@JS()
@anonymous
class _JsFs {
  external Object writeFile(String path, Object data);
  external Object readFile(String path, Object options);
}

class WebContainerProcess {
  final Stream<String> stdout;
  final Stream<String> stderr;
  final Future<int> exitCode;
  WebContainerProcess({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
}

class WebContainerService {
  _JsWebContainerInstance? _instance;

  bool get isBooted => _instance != null;

  Future<void> boot() async {
    if (!(_isCrossOriginIsolated())) {
      throw StateError(
        'Cross-origin isolation (COOP/COEP) is required for WebContainers. '
        'Serve the app with headers: COOP=same-origin and COEP=require-corp.',
      );
    }
    if (_instance != null) return;
    final jsInst = await jsu.promiseToFuture<Object>(_boot());
    _instance = jsInst as _JsWebContainerInstance;
  }

  Future<void> mount(Map<String, dynamic> tree) async {
    _ensureBooted();
    await jsu.promiseToFuture(
      jsu.callMethod(_instance!, 'mount', [jsu.jsify(tree)]),
    );
  }

  Future<void> writeFile(String path, Uint8List data) async {
    _ensureBooted();
    final fs = jsu.getProperty(_instance!, 'fs') as _JsFs;
    await jsu.promiseToFuture(jsu.callMethod(fs, 'writeFile', [path, data]));
  }

  WebContainerProcess spawn(String cmd, List<String> args) {
    _ensureBooted();
    final res = jsu.callMethod(_instance!, 'spawn', [cmd, args]);
    final jsOut = jsu.getProperty(res, 'output');
    final jsErr = jsu.getProperty(res, 'error');
    final jsExit = jsu.getProperty(res, 'exit');
    final outputStream = _readableStreamToDartStream(jsOut);
    final errorStream = _readableStreamToDartStream(jsErr);
    final Future<int> exitFut =
        jsExit != null ? jsu.promiseToFuture<int>(jsExit) : Future.value(-1);
    return WebContainerProcess(
      stdout: outputStream,
      stderr: errorStream,
      exitCode: exitFut,
    );
  }

  void onServerReady(void Function(int port, String url) cb) {
    _ensureBooted();
    jsu.callMethod(_instance!, 'on', [
      'server-ready',
      allowInterop((port, url) => cb((port as num).toInt(), url as String)),
    ]);
  }

  Stream<String> _readableStreamToDartStream(Object? jsStream) {
    if (jsStream == null) return const Stream.empty();
    final controller = StreamController<String>();
    final reader = jsu.callMethod(jsStream, 'getReader', []);

    void readNext() {
      jsu.promiseToFuture(jsu.callMethod(reader, 'read', [])).then((result) {
        final done = jsu.getProperty(result, 'done') as bool;
        final value = jsu.getProperty(result, 'value');
        if (!done && value != null) {
          if (value is String) {
            controller.add(value);
          } else {
            try {
              final buf = jsu.getProperty(value, 'buffer');
              if (buf != null) {
                controller.add(String.fromCharCodes(Uint8List.view(buf)));
              }
            } catch (_) {}
          }
          readNext();
        } else {
          controller.close();
        }
      });
    }

    readNext();
    return controller.stream;
  }

  void _ensureBooted() {
    if (_instance == null) {
      throw StateError('WebContainerService not booted. Call boot() first.');
    }
  }

  bool _isCrossOriginIsolated() {
    try {
      final val = jsu.getProperty(jsu.globalThis, 'crossOriginIsolated');
      return val == true;
    } catch (_) {
      return false;
    }
  }
}
