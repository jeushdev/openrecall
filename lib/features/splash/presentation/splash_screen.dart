import 'package:flutter/material.dart';

/// First frame shown on launch.
///
/// Routing is entirely the router's job now: `authRedirect` resolves `/` to
/// Login or the Deck Library based on the restored session, so this screen is
/// only visible for the brief moment before that runs.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
