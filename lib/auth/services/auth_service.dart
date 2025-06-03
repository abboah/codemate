import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Initialize Supabase
  final _supabase = Supabase.instance.client;

  // Login with Email and Password
  Future<AuthResponse> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign Up with Email and Password
  Future<AuthResponse> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Login With Google
  Future<bool> continueWithGoogle() async {
    return await _supabase.auth.signInWithOAuth(OAuthProvider.google);
  }

  //Logout
  Future<void> logout() async {
    return await _supabase.auth.signOut();
  }
}
