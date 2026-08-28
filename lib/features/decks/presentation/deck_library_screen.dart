import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';

/// Stub Deck Library / dashboard.
///
/// Milestone 1: an empty-state placeholder only.
/// Milestone 3: the settings menu holds "Log out" until the real Settings
/// screen arrives.
///
/// TODO(milestone 4): load the user's decks from Supabase (name, mastery %,
/// due/total counts, last-studied) and wire the "+" to the create-deck flow.
class DeckLibraryScreen extends ConsumerWidget {
  const DeckLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            // TODO(milestone 12): replace with a real Settings screen.
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
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
