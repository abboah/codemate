import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/services/web_container_service.dart';
import 'package:codemate/providers/project_files_provider.dart';
import 'package:codemate/models/project_file.dart';
import 'package:codemate/themes/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LivePreviewIdeView extends ConsumerStatefulWidget {
  final String projectId;
  const LivePreviewIdeView({super.key, required this.projectId});

  @override
  ConsumerState<LivePreviewIdeView> createState() => _LivePreviewIdeViewState();
}

class _LivePreviewIdeViewState extends ConsumerState<LivePreviewIdeView> {
  final _svc = WebContainerService();
  String? _previewUrl;
  bool _booting = false;
  bool _installing = false;
  bool _running = false;
  final List<String> _logs = [];
  WebViewController? _webViewController;

  void _appendLog(String s) {
    setState(
      () => _logs.add(
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $s',
      ),
    );
  }

  Future<void> _start() async {
    if (!kIsWeb) {
      _appendLog('Live Preview is only available on web.');
      return;
    }

    setState(() {
      _previewUrl = null;
      _booting = true;
      _installing = false;
      _running = false;
      _logs.clear();
    });

    try {
      await _svc.boot();
      _appendLog('WebContainer booted.');
      setState(() => _booting = false);

      // Mount project files
      final filesState = ref.read(projectFilesProvider(widget.projectId));
      if (filesState.isLoading) {
        await filesState.fetchFiles();
      }
      final tree = _buildMountTree(filesState.files);
      await _svc.mount(tree);
      _appendLog('Project files mounted.');

      // Install deps (defensive guards)
      setState(() => _installing = true);
      try {
        final install = _svc.spawn('npm', const ['install']);
        install.stdout.listen(
          (chunk) => _appendLog('[INSTALL] $chunk'),
          onError: (e) {
            _appendLog('[INSTALL] stdout error: $e');
          },
        );
        install.stderr.listen(
          (chunk) => _appendLog('[INSTALL ERROR] $chunk'),
          onError: (e) {
            _appendLog('[INSTALL] stderr error: $e');
          },
        );
        final code = await install.exitCode;
        _appendLog('npm install exited with code $code');

        if (code != 0) {
          _appendLog('Install failed. This may happen if:');
          _appendLog('- No package.json exists in the project');
          _appendLog('- Network issues preventing package downloads');
          _appendLog('- WebContainer environment restrictions');
          if (mounted) {
            setState(() {
              _installing = false;
              _running = false;
            });
          }
          return;
        }
      } catch (e) {
        _appendLog('npm install failed: $e');
        if (mounted) {
          setState(() {
            _installing = false;
            _running = false;
          });
        }
        return;
      } finally {
        if (mounted) setState(() => _installing = false);
      }

      // Run dev server
      setState(() => _running = true);
      try {
        final dev = _svc.spawn('npm', const ['run', 'dev']);
        dev.stdout.listen(
          (chunk) => _appendLog('[DEV] $chunk'),
          onError: (e) {
            _appendLog('[DEV] stdout error: $e');
          },
        );
        dev.stderr.listen(
          (chunk) => _appendLog('[DEV ERROR] $chunk'),
          onError: (e) {
            _appendLog('[DEV] stderr error: $e');
          },
        );
      } catch (e) {
        _appendLog('npm run dev failed: $e');
        if (mounted) {
          setState(() => _running = false);
        }
      }

      _svc.onServerReady((port, url) {
        _appendLog('Dev server ready on port $port: $url');
        if (!mounted) return;
        setState(() => _previewUrl = url);
        // Initialize or update WebView
        if (_webViewController == null) {
          final c =
              WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(url));
          setState(() => _webViewController = c);
        } else {
          _webViewController!.loadRequest(Uri.parse(url));
        }
      });
    } catch (e) {
      _appendLog('Error: $e');
      setState(() {
        _booting = false;
        _installing = false;
        _running = false;
      });
    }
  }

  Map<String, dynamic> _buildMountTree(List<ProjectFile> files) {
    final root = <String, dynamic>{};

    void ensurePath(List<String> parts, String content) {
      Map<String, dynamic> node = root;
      for (int i = 0; i < parts.length; i++) {
        final isFile = i == parts.length - 1;
        final name = parts[i];
        if (isFile) {
          node[name] = {
            'file': {'contents': content},
          };
        } else {
          node =
              (node[name] ??= {'directory': <String, dynamic>{}})['directory']
                  as Map<String, dynamic>;
        }
      }
    }

    for (final f in files) {
      final path = f.path.replaceAll('\\', '/');
      final content = f.content;
      ensurePath(path.split('/'), content);
    }
    return root;
  }

  // No-op: using WebViewWidget instead of custom iframe registration.

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 960,
        height: 640,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE PREVIEW',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed:
                        (_booting || _installing || _running) ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                      child:
                          _previewUrl == null
                              ? Center(
                                child: Text(
                                  _installing
                                      ? 'Installing dependencies…'
                                      : _booting
                                      ? 'Booting WebContainer…'
                                      : 'Click Run to start preview',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              )
                              : (_webViewController == null
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : WebViewWidget(
                                    controller: _webViewController!,
                                  )),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder:
                            (_, i) => Text(
                              _logs[i],
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
