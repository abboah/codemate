import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A simple model for our user profile data
class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final bool hasCompletedOnboarding;

  UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.hasCompletedOnboarding,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      username: map['username'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      hasCompletedOnboarding: map['has_completed_onboarding'] ?? false,
    );
  }
}

// The provider to fetch the user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return null;
  }
  try {
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    
    if (response == null) {
      return null;
    }
    return UserProfile.fromMap(response);
  } catch (e) {
    // Handle cases where the profile might not exist yet or other errors
    return null;
  }
});
