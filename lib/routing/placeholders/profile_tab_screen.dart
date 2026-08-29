import 'package:flutter/material.dart';

/// Placeholder for the Profile tab (`/profile`, ui-spec-v1 §6.4).
///
/// The real profile view arrives in U8 alongside Settings.
class ProfileTabScreen extends StatelessWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Profile')),
    );
  }
}
