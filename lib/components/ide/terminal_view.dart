import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TerminalView extends ConsumerStatefulWidget {
  final String projectId;
  final String? sessionId; // optional existing session

  const TerminalView({super.key, required this.projectId, this.sessionId});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_TerminalLine> _lines = [];
  String _cwd = '/';
  String? _sessionId;
  bool _busy = false;

  // Sessions drawer
  bool _showHistory = false;
  List<Map<String, dynamic>> _sessions = [];

  // Path suggestions
  bool _showPathSuggestions = false;
  List<_PathEntry> _suggestions = [];
  int _selectedSuggestion = 0;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _input.addListener(_onInputChanged);
    _fetchSessions();
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSessions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final res = await Supabase.instance.client
          .from('terminal_sessions')
          .select('id, name, created_at')
          .eq('project_id', widget.projectId)
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      setState(() => _sessions = List<Map<String, dynamic>>.from(res as List));
    } catch (_) {}
  }

  Future<void> _ensureSession() async {
    if (_sessionId != null) return;
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final res = await Supabase.instance.client
        .from('terminal_sessions')
        .insert({ 'project_id': widget.projectId, 'user_id': userId, 'name': null })
        .select('id')
        .single();
    _sessionId = res['id'] as String;
    _fetchSessions();
  }

  Future<void> _loadSession(String sessionId) async {
    setState(() {
      _sessionId = sessionId;
      _lines.clear();
      _cwd = '/';
    });
    try {
      final rows = await Supabase.instance.client
          .from('terminal_commands')
          .select('command, output, cwd, created_at')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);
      for (final row in (rows as List)) {
        final cmd = row['command'] as String? ?? '';
        final out = row['output'] as String? ?? '';
        final cwd = row['cwd'] as String? ?? '/';
        setState(() {
          _lines.add(_TerminalLine(prefix: '\u0000', text: '\u0000')); // spacing
          _lines.add(_TerminalLine(prefix: '$cwd >', text: cmd));
          if (out.isNotEmpty) {
            for (final line in out.split('\n')) {
              _lines.add(_TerminalLine(prefix: '', text: line));
            }
          }
          _cwd = cwd;
        });
      }
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _runCommand(String command) async {
    if (command.trim().isEmpty) return;
    setState(() => _busy = true);

    await _ensureSession();
    setState(() {
      _lines.add(_TerminalLine(prefix: '\u0000', text: '\u0000')); // spacing marker
      _lines.add(_TerminalLine(prefix: _prompt(), text: command));
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'terminal-handler',
        body: { 'command': command, 'projectId': widget.projectId, 'currentDirectory': _cwd, 'sessionId': _sessionId },
      );
      if (response.status != 200) throw Exception(response.data);
      final data = response.data as Map<String, dynamic>;
      final output = (data['output'] as String?) ?? '';
      final exitCode = (data['exitCode'] as int?) ?? 0;
      final nextCwd = (data['cwd'] as String?) ?? _cwd;

      setState(() {
        if (output.isNotEmpty) {
          for (final line in output.split('\n')) {
            _lines.add(_TerminalLine(prefix: '', text: line));
          }
        }
        _cwd = nextCwd;
      });

      // Persist command
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('terminal_commands').insert({
        'session_id': _sessionId,
        'project_id': widget.projectId,
        'user_id': userId,
        'command': command,
        'output': output,
        'exit_code': exitCode,
        'cwd': _cwd,
      });
    } catch (e) {
      setState(() {
        _lines.add(_TerminalLine(prefix: '', text: 'Error: $e'));
      });
    } finally {
      setState(() => _busy = false);
      _scrollToBottom();
    }
  }

  void _onInputChanged() {
    final text = _input.text;
    final lastToken = text.split(RegExp(r'\s+')).last;
    final slashIndex = lastToken.lastIndexOf('/');
    if (slashIndex != -1) {
      _computeSuggestions(baseToken: lastToken.substring(0, slashIndex), fragment: lastToken.substring(slashIndex + 1));
    } else if (text.endsWith('/')) {
      _computeSuggestions(baseToken: '', fragment: '');
    } else {
      if (_showPathSuggestions) setState(() => _showPathSuggestions = false);
    }
  }

  Future<void> _computeSuggestions({required String baseToken, required String fragment}) async {
    // Determine base directory for suggestions
    String baseDir;
    if (baseToken.isEmpty) {
      baseDir = _cwd;
    } else if (baseToken.startsWith('/')) {
      baseDir = _normalizePath(baseToken);
    } else {
      baseDir = _normalizePath(_cwd + '/' + baseToken);
    }

    final entries = await _loadImmediateChildren(baseDir);
    final filtered = entries
        .where((e) => fragment.isEmpty || e.name.toLowerCase().startsWith(fragment.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _suggestions = filtered;
      _selectedSuggestion = 0;
      _showPathSuggestions = filtered.isNotEmpty;
    });
  }

  Future<List<_PathEntry>> _loadImmediateChildren(String dir) async {
    final dirKey = dir == '/' ? '' : (dir.startsWith('/') ? dir.substring(1) : dir);
    final pattern = dirKey.isEmpty ? '%' : '$dirKey/%';
    final res = await Supabase.instance.client
        .from('project_files')
        .select('path')
        .eq('project_id', widget.projectId)
        .like('path', pattern)
        .order('path');
    final paths = List<Map<String, dynamic>>.from(res as List).map((r) => r['path'] as String).toList();
    final names = <String, bool>{}; // name -> isDir
    for (final p in paths) {
      final rest = dirKey.isEmpty ? p : p.replaceFirst(RegExp('^' + RegExp.escape(dirKey) + '/?'), '');
      if (rest.isEmpty) continue;
      final parts = rest.split('/');
      final name = parts.first;
      final isDir = parts.length > 1;
      names[name] = names[name] == true || isDir;
    }
    return names.entries.map((e) => _PathEntry(name: e.key, isDir: e.value)).toList();
  }

  Future<void> _onTabPressed() async {
    if (_showPathSuggestions && _suggestions.isNotEmpty) {
      _applySuggestion(_suggestions[_selectedSuggestion]);
      return;
    }
    // Prime suggestions based on current token and then apply first if any
    final text = _input.text;
    final lastToken = text.split(RegExp(r'\s+')).last;
    final slashIndex = lastToken.lastIndexOf('/');
    String baseToken = '';
    String fragment = '';
    if (slashIndex != -1) {
      baseToken = lastToken.substring(0, slashIndex);
      fragment = lastToken.substring(slashIndex + 1);
    } else if (text.endsWith('/')) {
      baseToken = '';
      fragment = '';
    } else {
      // no slash context; show current cwd children
      baseToken = '';
      fragment = lastToken;
    }
    await _computeSuggestions(baseToken: baseToken, fragment: fragment);
    if (_suggestions.isNotEmpty) {
      _applySuggestion(_suggestions.first);
    }
  }

  void _applySuggestion(_PathEntry entry) {
    // Replace current token's fragment with suggestion
    final text = _input.text;
    final parts = text.split(RegExp(r'\s+'));
    final last = parts.isNotEmpty ? parts.last : '';
    final slashIndex = last.lastIndexOf('/');
    String baseToken = '';
    String beforeAll = '';
    if (parts.length > 1) {
      beforeAll = parts.sublist(0, parts.length - 1).join(' ');
    }
    if (slashIndex != -1) {
      baseToken = last.substring(0, slashIndex);
    }
    final prefix = beforeAll.isEmpty ? '' : beforeAll + ' ';
    final base = baseToken.isEmpty ? '' : baseToken + '/';
    final suggested = base + entry.name + (entry.isDir ? '/' : '');
    _input.value = TextEditingValue(
      text: prefix + suggested,
      selection: TextSelection.collapsed(offset: (prefix + suggested).length),
    );
    if (entry.isDir) {
      _computeSuggestions(baseToken: suggested, fragment: '');
    } else {
      setState(() => _showPathSuggestions = false);
    }
  }

  String _normalizePath(String p) {
    final parts = p.split('/').where((e) => e.isNotEmpty).toList();
    final stack = <String>[];
    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..') {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        stack.add(part);
      }
    }
    return '/' + stack.join('/');
  }

  String _prompt() => '$_cwd >';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final watermarkStyle = GoogleFonts.poppins(
      color: Colors.white.withOpacity(0.035),
      fontSize: 56,
      fontWeight: FontWeight.w700,
      letterSpacing: 10,
    );

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 760,
          height: 520,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Header
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'History',
                          onPressed: () => setState(() => _showHistory = !_showHistory),
                          icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 20),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.terminal, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text('Terminal', style: GoogleFonts.poppins(color: Colors.white70)),
                        const Spacer(),
                        IconButton(
                          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  // History
                  Expanded(
                    child: Stack(
                      children: [
                        // Subtle background glyphs only behind the terminal content area
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _TerminalWallpaperPainter(textStyle: watermarkStyle),
                            ),
                          ),
                        ),
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _lines.length,
                          itemBuilder: (context, i) {
                            final l = _lines[i];
                            if (l.prefix == '\u0000') return const SizedBox(height: 4);
                            return RichText(
                              text: TextSpan(
                                style: GoogleFonts.robotoMono(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.6),
                                children: [
                                  if (l.prefix.isNotEmpty) TextSpan(text: '${l.prefix} ', style: const TextStyle(color: Colors.blueAccent)),
                                  TextSpan(text: l.text),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Input
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        Text(_prompt(), style: GoogleFonts.robotoMono(color: Colors.blueAccent)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Shortcuts(
                            shortcuts: <LogicalKeySet, Intent>{
                              LogicalKeySet(LogicalKeyboardKey.tab): const ActivateIntent(),
                            },
                            child: Actions(
                              actions: <Type, Action<Intent>>{
                                ActivateIntent: CallbackAction<Intent>(
                                  onInvoke: (intent) {
                                    _onTabPressed();
                                    return null;
                                  },
                                ),
                              },
                              child: TextField(
                                controller: _input,
                                style: GoogleFonts.robotoMono(color: Colors.white),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onSubmitted: (v) {
                                  final cmd = v.trim();
                                  _input.clear();
                                  setState(() => _showPathSuggestions = false);
                                  _runCommand(cmd);
                                },
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward, color: Colors.white70),
                          onPressed: _busy ? null : () {
                            final cmd = _input.text.trim();
                            _input.clear();
                            setState(() => _showPathSuggestions = false);
                            _runCommand(cmd);
                          },
                        )
                      ],
                    ),
                  ),
                ],
              ),
              // History drawer
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: _showHistory ? 0 : -280,
                top: 40,
                bottom: 0,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 40,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Sessions', style: GoogleFonts.poppins(color: Colors.white70)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final s = _sessions[index];
                            return ListTile(
                              dense: true,
                              title: Text(s['name'] ?? 'Session', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                              subtitle: Text((s['created_at'] ?? '').toString(), style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                              onTap: () {
                                _loadSession(s['id'] as String);
                                setState(() => _showHistory = false);
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FilledButton(
                          onPressed: () async {
                            setState(() { _sessionId = null; _lines.clear(); _cwd = '/'; });
                            await _ensureSession();
                            setState(() => _showHistory = false);
                          },
                          style: FilledButton.styleFrom(backgroundColor: Colors.blueAccent),
                          child: const Text('New session'),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              // Path suggestions overlay (bottom above input)
              if (_showPathSuggestions)
                Positioned(
                  left: 8 + 60, // prompt width approx
                  right: 8,
                  bottom: 52,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final e = _suggestions[index];
                        final selected = index == _selectedSuggestion;
                        return InkWell(
                          onTap: () => _applySuggestion(e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: selected ? Colors.white.withOpacity(0.06) : Colors.transparent,
                            child: Row(
                              children: [
                                Icon(e.isDir ? Icons.folder_rounded : Icons.insert_drive_file_outlined, size: 16, color: e.isDir ? Colors.amber : Colors.white70),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.isDir ? '${e.name}/' : e.name,
                                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalLine {
  final String prefix;
  final String text;
  _TerminalLine({required this.prefix, required this.text});
}

class _PathEntry {
  final String name;
  final bool isDir;
  _PathEntry({required this.name, required this.isDir});
}

class _TerminalWallpaperPainter extends CustomPainter {
  final TextStyle textStyle;
  _TerminalWallpaperPainter({required this.textStyle});

  @override
  void paint(Canvas canvas, Size size) {
    const word = 'ROBIN';
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final step = 160.0;
    for (double y = 20; y < size.height; y += step) {
      for (double x = 20; x < size.width; x += step) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.3); // subtle angle
        painter.text = TextSpan(text: word, style: textStyle);
        painter.layout();
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TerminalWallpaperPainter oldDelegate) {
    return false;
  }
} 