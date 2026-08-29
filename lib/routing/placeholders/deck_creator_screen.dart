import 'package:flutter/material.dart';

/// Placeholder for the Deck Creator (`/deck-creator`, ui-spec-v1 §4).
///
/// A top-level route outside the shell, so the bottom nav bar is naturally
/// absent while creating a deck. The real card-manager UI arrives in a later
/// milestone; this shares the [DeckCreatorScreen] name with the not-yet-rewired
/// screen in `lib/features/decks/presentation/` (different library, never
/// imported together).
class DeckCreatorScreen extends StatelessWidget {
  const DeckCreatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Deck Creator')),
    );
  }
}
