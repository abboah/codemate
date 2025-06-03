import 'package:codemate/auth/login_page.dart';
import 'package:codemate/home/homepage.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Loading Screen...to be implemented
        Scaffold(body: Center(child: CircularProgressIndicator()));
        final session = snapshot.hasData ? snapshot.data : null;

        if (session != null) {
          return HomePage();
        } else {
          return LoginPage();
        }
      },
    );
  }
}
