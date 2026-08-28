import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../auth/application/auth_providers.dart';
import '../application/deck_providers.dart';
import 'widgets/create_deck_dialog.dart';
import 'widgets/deck_tile.dart';

/// The Deck Library / dashboard (spec §2): the list of the user's decks, a
/// create-deck action, and the settings menu.
class DeckLibraryScreen extends ConsumerWidget {
  const DeckLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(decksControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Something went wrong: $error')));
      }
    });

    final decks = ref.watch(decksProvider);

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
      body: decks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(onRetry: () => ref.invalidate(decksProvider)),
        data: (decks) => decks.isEmpty
            ? const _EmptyLibrary()
            : ListView.builder(
                itemCount: decks.length,
                itemBuilder: (context, i) => DeckTile(
                  summary: decks[i],
                  onTap: () => _openDeck(context, decks[i].id, decks[i].name),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDeck(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Create deck'),
      ),
    );
  }

  Future<void> _createDeck(BuildContext context, WidgetRef ref) async {
    final name = await showCreateDeckDialog(context);
    if (name == null) return;

    final deck =
        await ref.read(decksControllerProvider.notifier).createDeck(name);
    if (deck == null || !context.mounted) return;

    _openDeck(context, deck.id, deck.name);
  }

  void _openDeck(BuildContext context, String deckId, String deckName) {
    context.pushNamed(
      AppRoutes.deckCreatorName,
      pathParameters: {'deckId': deckId},
      extra: deckName,
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No decks yet.\nCreate your first deck to get started.',
          textAlign: TextAlign.center,
        ),
        // TODO(milestone 14): link to a small pre-made sample deck here.
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load your decks."),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
