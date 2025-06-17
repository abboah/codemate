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
  ) async {
    final res = await _supabase.auth.signUp(email: email, password: password);
    if (res.user == null) {
      throw Exception("Sign-up failed. Try again.");
    }
    return res;
  }

  Future<void> continueWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,

        redirectTo:
            kIsWeb
                ? const String.fromEnvironment(
                  'PROD_URL',
                  defaultValue: 'http://localhost:59600/',
                )
                : null,

        // 'http://localhost:59600/', // or production URL
      );
    } catch (e) {
      throw Exception("Google sign-in failed: $e");
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
