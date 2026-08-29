import 'package:flutter/material.dart';

/// Placeholder for the Settings tab (`/settings`, ui-spec-v1 §6.5).
///
/// The real settings view (locally-persisted toggles, sign-out with
/// unsynced-writes detection) arrives in U8.
class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Settings')),
    );
  }
}
