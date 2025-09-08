// Conditional export: if JS interop is available, export the web implementation;
// otherwise export a stub that throws with a clear message.
export 'web_container_service_stub.dart'
    if (dart.library.js) 'web_container_service_web.dart';
