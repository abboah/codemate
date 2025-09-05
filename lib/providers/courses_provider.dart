import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Course {
  final String id;
  final String title;
  final String description;

  Course({required this.id, required this.title, required this.description});

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
    );
  }
}

final coursesProvider = ChangeNotifierProvider((ref) => CoursesProvider());

class CoursesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  List<Course> _courses = [];
  int _enrolledCoursesCount = 0;
  bool _isLoading = false;
  String? _error;

  List<Course> get courses => _courses;
  int get enrolledCoursesCount => _enrolledCoursesCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCourses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client
          .from('courses')
          .select()
          .order('created_at', ascending: false);

      _courses = (response as List).map((item) => Course.fromMap(item)).toList();
    } catch (e) {
      _error = 'Failed to fetch courses: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEnrolledCoursesCount() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('enrollments')
          .select('course_id')
          .eq('user_id', userId);
      _enrolledCoursesCount = response.length;
      notifyListeners();
    } catch (e) {
      // Handle error appropriately
      debugPrint('Failed to fetch enrolled courses count: $e');
    }
  }
}