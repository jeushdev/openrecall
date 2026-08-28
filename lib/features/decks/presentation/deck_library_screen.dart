import 'package:flutter/material.dart';

/// Stub Deck Library / dashboard.
///
/// Milestone 1: an empty-state placeholder only.
///
/// TODO(milestone 4): load the user's decks from Supabase (name, mastery %,
/// due/total counts, last-studied), wire the "+" to the create-deck flow,
/// and the settings icon to the Settings screen (spec §2).
class DeckLibraryScreen extends StatelessWidget {
  const DeckLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {}, // TODO(milestone 12): open Settings.
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No decks yet.\nCreate your first deck to get started.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // TODO(milestone 4): create-deck flow.
        icon: const Icon(Icons.add),
        label: const Text('Create deck'),
      ),
    );
  }
}
