import 'package:codemate/auth/auth_gate.dart';
import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/signup_page.dart';
import 'package:codemate/chatbot/chatbot.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/layouts/dashboard_page.dart';
import 'package:codemate/layouts/option3.dart';
import 'package:codemate/paths/learning_paths_page.dart';
import 'package:codemate/providers/user_provider.dart';
import 'package:codemate/screens/build_page.dart';
import 'package:codemate/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:codemate/screens/tour_screen.dart';
import 'package:codemate/screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93dnNrcHduaWRrbmdvZ2ZzbWJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg0Mzc2NTgsImV4cCI6MjA2NDAxMzY1OH0.abo3H246wUXjQNEmV3ASSYepXq1g1zul_NliYJjYVQQ",
    url: "https://owvskpwnidkngogfsmby.supabase.co",
  );
  runApp(ProviderScope(child: const MyApp()));
}

// Removed duplicate MyApp StatelessWidget. Only ConsumerStatefulWidget version is used below.
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);
final isNewUserProvider = StateProvider<bool?>((ref) => null);
//final authState = ref.watch(supabaseAuthStateProvider);
// Replace with your actual user provider
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

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(supabaseAuthStateProvider);

    return authStateAsync.when(
      loading:
          () => const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (err, _) => MaterialApp(
            home: Scaffold(body: Center(child: Text('Auth Error: $err'))),
          ),
      data: (authState) {
        final user = authState.session?.user;
        if (user == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            darkTheme: darkTheme,
            themeMode: ThemeMode.dark,
            home: const LandingPage(),
          );
        }

        // 🔥 Fetch profile here
        return FutureBuilder<UserProfile?>(
          future: _getOrCreateUserProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: Text("Could not load user profile.")),
                ),
              );
            }

            final hasCompletedOnboarding = profile.hasCompletedOnboarding;

            return MaterialApp(
              title: 'Robin',
              debugShowCheckedModeBanner: false,
              darkTheme: darkTheme,
              themeMode: ThemeMode.dark,
              home:
                  hasCompletedOnboarding
                      ? HomeScreen(profile: profile)
                      : TourScreen(profile: profile),
              routes: {
                '/dashboard': (_) => const RobinDashboardMinimal(),
                '/chatbot': (_) => ModernDrawerScaffold(child: Chatbot()),
                '/build': (_) => ModernDrawerScaffold(child: BuildPage()),
                '/paths':
                    (_) => ModernDrawerScaffold(child: LearningPathsPage()),
                '/select': (_) => HomeScreen(profile: profile),
              },
            );
          },
        );
      },
    );
  }
}

class ModernDrawerScaffold extends StatelessWidget {
  final Widget child;

  const ModernDrawerScaffold({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robin'),
        centerTitle: true,
        backgroundColor: Colors.grey[900],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Icon(Icons.flutter_dash, color: Colors.blue, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      'Robin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Icon(Icons.dashboard_rounded, color: Colors.white),
                title: Text('Dashboard', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => RobinDashboardMinimal()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.folder_rounded, color: Colors.white),
                title: Text('Projects', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => BuildPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.school_rounded, color: Colors.white),
                title: Text(
                  'Learning Paths',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LearningPathsPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.chat_bubble_rounded, color: Colors.white),
                title: Text(
                  'AI Assistant',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => Chatbot()),
                  );
                },
              ),
              const Spacer(),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: Text(
                  'Log Out',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LandingPage()),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      body: child,
    );
  }
}
