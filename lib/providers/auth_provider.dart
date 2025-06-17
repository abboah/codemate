// providers/auth_provider.dart
import 'package:codemate/auth/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provides the AuthService using the Supabase client
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = Supabase.instance.client;
  return AuthService(supabase);
});
final authUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});
