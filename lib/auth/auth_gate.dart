import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/home_screen.dart';
import 'package:codemate/screens/tour_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  Future<UserProfile?> _getOrCreateUserProfile() async {
    try {
      // Call the RPC function on the database.
      final response = await Supabase.instance.client.rpc('get_or_create_user');
      
      // The RPC returns a list of rows. It might be empty.
      final userList = response as List;
      if (userList.isEmpty) {
        // This is the critical check. If the list is empty, something is wrong.
        debugPrint("Error: get_or_create_user returned no user.");
        return null;
      }

      final userMap = userList.first as Map<String, dynamic>;
      return UserProfile.fromMap(userMap);
    } catch (e) {
      // If any other error occurs, return null to signify failure.
      debugPrint("Error in get_or_create_user: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(supabaseAuthStateProvider);

    return authState.when(
      data: (data) {
        final user = data.session?.user;
        if (user == null) {
          return const LandingPage();
        } else {
          return FutureBuilder<UserProfile?>(
            future: _getOrCreateUserProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              
              final profile = snapshot.data;
              if (profile == null) {
                return const Scaffold(body: Center(child: Text("Could not load user profile.")));
              }

              final hasCompletedOnboarding = profile.hasCompletedOnboarding;

              return hasCompletedOnboarding
                  ? HomeScreen(profile: profile)
                  : TourScreen(profile: profile);
            },
          );
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}

// It's better to watch the auth state changes directly from the Supabase client
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
