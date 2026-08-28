import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';

/// First screen shown on launch.
///
/// Milestone 1: waits a fixed delay, then routes to Login.
///
/// TODO(milestone 3): replace the timed delay with a real Supabase auth
/// check — route to Deck Library when a session exists, Login otherwise.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashDelay = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _advance();
  }

  Future<void> _advance() async {
    await Future<void>.delayed(_splashDelay);
    if (!mounted) return;
    context.goNamed(AppRoutes.loginName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'OpenRecall',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
