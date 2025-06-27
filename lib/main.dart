import 'package:codemate/auth/auth_gate.dart';
import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/signup_page.dart';
import 'package:codemate/chatbot/chatbot.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/layouts/option2.dart';
import 'package:codemate/layouts/option3.dart';
import 'package:codemate/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: RobinDashboardMinimal(),
    );
  }
}
