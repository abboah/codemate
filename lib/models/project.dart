class Project {
  final String id;
  final String name;
  final String description;

  Project({required this.id, required this.name, required this.description});

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      description: map['description'] ?? '',
    );
  }
}
