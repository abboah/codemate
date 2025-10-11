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
import 'package:url_launcher/url_launcher.dart';

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
  bool _expanded = false;
  int? _port;
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
      // Early warning if COOP/COEP are missing
      if (!(identical(1, 1))) {}
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
        setState(() {
          _previewUrl = url;
          _port = port;
        });
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
  String _statusText() {
    if (_previewUrl != null)
      return 'Ready' + (_port != null ? '  ·  port $_port' : '');
    if (_running) return 'Starting dev server…';
    if (_installing) return 'Installing dependencies…';
    if (_booting) return 'Booting WebContainer…';
    return 'Click Run to start preview';
  }

  Future<void> _openInNewTab() async {
    final url = _previewUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final double boxWidth =
        _expanded ? (screen.width - 32).clamp(320.0, screen.width) : 960;
    final double boxHeight =
        _expanded ? (screen.height - 96).clamp(320.0, screen.height) : 640;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: boxWidth,
        height: boxHeight,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F1016), Color(0xFF0C0D12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7F5AF0), Color(0xFF9D4EDD)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F5AF0).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Preview',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusText(),
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_previewUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Tooltip(
                        message: 'Open in new tab',
                        child: IconButton(
                          onPressed: _openInNewTab,
                          icon: const Icon(
                            Icons.open_in_new,
                            size: 18,
                            color: Colors.white70,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Tooltip(
                    message: _expanded ? 'Exit Fullscreen' : 'Fullscreen',
                    child: IconButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white70,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Close',
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed:
                        (_booting || _installing || _running) ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      'Run',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
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
                              ? _EmptyState(status: _statusText())
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'LOGS',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => setState(() => _logs.clear()),
                                icon: const Icon(
                                  Icons.cleaning_services_outlined,
                                  size: 16,
                                ),
                                label: const Text('Clear'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white60,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            child: ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder:
                                  (_, i) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                    ),
                                    child: Text(
                                      _logs[i],
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
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
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;
  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF23A6D5), Color(0xFF12D8FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF23A6D5).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.web_asset, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              status,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll boot a WebContainer and run your dev server here.',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
