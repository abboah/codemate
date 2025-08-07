import 'package:flutter/foundation.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final List<String> stack;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.stack,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'] ?? 'Untitled Project',
      description: map['description'] ?? 'No description provided.',
      stack: List<String>.from(map['stack'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Project &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      listEquals(other.stack, stack) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      stack.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }
}
