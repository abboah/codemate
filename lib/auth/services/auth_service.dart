// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class AuthService {
//   // Initialize Supabase
//   final _supabase = Supabase.instance.client;

//   // Login with Email and Password
//   Future<AuthResponse> loginWithEmailAndPassword(
//     String email,
//     String password,
//   ) async {
//     return await _supabase.auth.signInWithPassword(
//       email: email,
//       password: password,
//     );
//   }

//   // Sign Up with Email and Password
//   Future<AuthResponse> signUpWithEmailAndPassword(
//     String email,
//     String password,
//   ) async {
//     return await _supabase.auth.signUp(email: email, password: password);
//   }

//   // Login With Google
//   Future<bool> continueWithGoogle() async {
//     return await _supabase.auth.signInWithOAuth(OAuthProvider.google);
//   }

//   //Logout
//   Future<void> logout() async {
//     return await _supabase.auth.signOut();
//   }
// }
// services/auth_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // final authUserProvider = StreamProvider<User?>((ref) {
  //   return Supabase.instance.client.auth.onAuthStateChange.map(
  //     (event) => event.session?.user,
  //   );
  // });

  Future<AuthResponse> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final res = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.user == null) {
      throw Exception("Login failed. Please check credentials.");
    }
    return res;
  }

  Future<AuthResponse> signUpWithEmailAndPassword(
    String email,
    String password,
    String fullName,
  ) async {
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (res.user == null) {
      throw Exception("Sign-up failed. Try again.");
    }
    return res;
  }

  Future<void> continueWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
      );
    } catch (e) {
      throw Exception("Google sign-in failed: $e");
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  Future<void> deleteAccount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }
    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<String> uploadAvatar(File image) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = fileName;

    try {
      await _supabase.storage.from('profile-pictures').upload(path, image);
      final imageUrl = _supabase.storage.from('profile-pictures').getPublicUrl(path);
      await _supabase.from('users').update({'avatar_url': imageUrl}).eq('id', userId);
      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }
}
