class ProjectFile {
  final String id;
  final String projectId;
  final String path;
  final String content;
  final DateTime createdAt;
  final DateTime lastModified;

  ProjectFile({
    required this.id,
    required this.projectId,
    required this.path,
    required this.content,
    required this.createdAt,
    required this.lastModified,
  });

  factory ProjectFile.fromMap(Map<String, dynamic> map) {
    return ProjectFile(
      id: map['id'],
      projectId: map['project_id'],
      path: map['path'],
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      lastModified: DateTime.parse(map['last_modified']),
    );
  }

  ProjectFile copyWith({
    String? id,
    String? projectId,
    String? path,
    String? content,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return ProjectFile(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}
