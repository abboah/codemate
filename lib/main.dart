import 'package:codemate/auth/auth_gate.dart';
import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/signup_page.dart';
import 'package:codemate/chatbot/chatbot.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/layouts/dashboard_page.dart';
import 'package:codemate/layouts/option3.dart';
import 'package:codemate/paths/learning_paths_page.dart';
import 'package:codemate/themes/theme.dart';
import 'package:flutter/material.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robin',
      debugShowCheckedModeBanner: false,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: AuthGate(),
      builder: (context, child) {
        return _ModernDrawerScaffold(child: child!);
      },
    );
  }
}

class _ModernDrawerScaffold extends StatelessWidget {
  final Widget child;
  const _ModernDrawerScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            scaffoldKey.currentState?.openDrawer();
          },
        ),
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
              // Add your logo or user avatar here
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
              // Navigation items
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
                onTap: () {},
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
                  // TODO: Add logout logic
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
