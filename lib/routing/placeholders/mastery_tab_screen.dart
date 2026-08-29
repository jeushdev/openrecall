import 'package:flutter/material.dart';

/// Placeholder for the Mastery tab (`/mastery`, ui-spec-v1 §6.3).
///
/// The real three-section mastery view (overall, courses, troublemakers) lands
/// in U7 against the Engine V2 aggregation providers.
class MasteryTabScreen extends StatelessWidget {
  const MasteryTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mastery')),
    );
  }
}
