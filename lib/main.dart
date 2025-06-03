import 'package:codemate/auth/auth_gate.dart';
import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/signup_page.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprZnp5cmx1aGtqcndkZGloZ3V6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg0NTE2MDMsImV4cCI6MjA2NDAyNzYwM30.subMzf18C58axW325rZhGWdKMEDzZzXaBiFX1pP_G0c",
    url: "https://zkfzyrluhkjrwddihguz.supabase.co",
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProjectX Code Learning',
      debugShowCheckedModeBanner: false,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const LoginPage(),
    );
  }
}
