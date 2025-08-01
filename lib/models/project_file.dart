class ProjectFile {
  final String id;
  final String projectId;
  final String filePath;
  final String fileName;
  final String content;
  final String fileType;

  ProjectFile({
    required this.id,
    required this.projectId,
    required this.filePath,
    required this.fileName,
    required this.content,
    required this.fileType,
  });

  factory ProjectFile.fromMap(Map<String, dynamic> map) {
    return ProjectFile(
      id: map['id'],
      projectId: map['project_id'],
      filePath: map['file_path'],
      fileName: map['file_name'],
      content: map['content'] ?? '',
      fileType: map['file_type'] ?? '',
    );
  }
}
