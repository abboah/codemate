import 'package:codemate/models/project_file.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FileSearchDialog extends StatefulWidget {
  final List<ProjectFile> files;

  const FileSearchDialog({super.key, required this.files});

  @override
  State<FileSearchDialog> createState() => _FileSearchDialogState();
}

class _FileSearchDialogState extends State<FileSearchDialog> {
  late final TextEditingController _searchController;
  late List<ProjectFile> _filteredFiles;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredFiles = widget.files;
    _searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFiles);
    _searchController.dispose();
    super.dispose();
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFiles = widget.files
          .where((file) => file.path.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Attach Code',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredFiles.length,
                  itemBuilder: (context, index) {
                    final file = _filteredFiles[index];
                    return ListTile(
                      title: Text(file.path, style: const TextStyle(color: Colors.white)),
                      onTap: () => Navigator.of(context).pop(file),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
