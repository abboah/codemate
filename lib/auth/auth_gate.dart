import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/services/auth_service.dart';
import 'package:codemate/home/homepage.dart';
import 'package:codemate/landing_page/landing_page.dart';
import 'package:codemate/layouts/option2.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authUserProvider);

    return authUser.when(
      data: (user) {
        return user != null
            ? const RobinDashboardMinimal()
            : const LandingPage();
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}
