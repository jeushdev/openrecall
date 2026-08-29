import 'package:flutter/material.dart';

/// Placeholder for the Decks tab (`/decks`, ui-spec-v1 §6.1).
///
/// Milestone U2 only wires routing; the real segmented Due/All control and deck
/// grid arrive in U4. Kept as a bare [Scaffold] so the shell's [IndexedStack]
/// has something to preserve per branch.
class DecksTabScreen extends StatelessWidget {
  const DecksTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Decks')),
    );
  }
}
