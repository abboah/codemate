import 'package:codemate/providers/project_files_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AttachCodeDialog extends ConsumerStatefulWidget {
  final String projectId;
  final List<String> initiallySelectedPaths;

  const AttachCodeDialog({super.key, required this.projectId, this.initiallySelectedPaths = const []});

  @override
  ConsumerState<AttachCodeDialog> createState() => _AttachCodeDialogState();
}

class _AttachCodeDialogState extends ConsumerState<AttachCodeDialog> {
  late Set<String> _selectedPaths;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedPaths = widget.initiallySelectedPaths.toSet();
    // Ensure files are loaded
    ref.read(projectFilesProvider(widget.projectId).notifier).fetchFiles();
  }

  @override
  Widget build(BuildContext context) {
    final filesState = ref.watch(projectFilesProvider(widget.projectId));
    final files = filesState.files
        .where((f) => _query.isEmpty || f.path.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.code, color: Colors.white70),
                const SizedBox(width: 8),
                Text('Attach code', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white60),
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search files…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 360),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: filesState.isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final selected = _selectedPaths.contains(file.path);
                        return InkWell(
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedPaths.remove(file.path);
                            } else {
                              _selectedPaths.add(file.path);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? Colors.blueAccent : Colors.white38, size: 18),
                                const SizedBox(width: 10),
                                const Icon(Icons.description_outlined, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    file.path,
                                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  onPressed: _selectedPaths.isEmpty
                      ? null
                      : () {
                          final allFilesProvider = ref.read(projectFilesProvider(widget.projectId));
                          final selectedMaps = allFilesProvider.files
                              .where((f) => _selectedPaths.contains(f.path))
                              .map((f) => {'path': f.path, 'content': f.content, 'file_id': f.id})
                              .toList();
                          Navigator.of(context).pop(selectedMaps);
                        },
                  label: Text('Attach (${_selectedPaths.length})', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 