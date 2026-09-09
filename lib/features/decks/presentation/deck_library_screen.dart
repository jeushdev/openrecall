import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../application/deck_providers.dart';
import '../application/offline_providers.dart';
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
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

    final decks = ref.watch(decksProvider);
    // No local mirror on web, so no deck is ever "downloaded"
    // (spec-web-mvp §5.3).
    final offlineIds = kIsWeb
        ? const <String>{}
        : ref.watch(studiableOfflineDeckIdsProvider).asData?.value ??
              const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.pushNamed(AppRoutes.settingsName),
          ),
        ],
      ),
      body: decks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _LoadError(onRetry: () => ref.invalidate(decksProvider)),
        data: (decks) => decks.isEmpty
            ? const _EmptyLibrary()
            : ListView.builder(
                itemCount: decks.length,
                itemBuilder: (context, i) => DeckTile(
                  summary: decks[i],
                  offline: offlineIds.contains(decks[i].id),
                  onTap: () =>
                      _openOverview(context, decks[i].id, decks[i].name),
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

    final deck = await ref
        .read(decksControllerProvider.notifier)
        .createDeck(name);
    if (deck == null || !context.mounted) return;

    // Spec §2: a brand-new deck goes straight into the Deck Creator to add
    // cards, skipping the (empty) Overview. Back still returns to the library.
    context.pushNamed(
      AppRoutes.deckCreatorName,
      pathParameters: {'deckId': deck.id},
      extra: deck.name,
    );
  }

  void _openOverview(BuildContext context, String deckId, String deckName) {
    context.pushNamed(
      AppRoutes.deckOverviewName,
      pathParameters: {'deckId': deckId},
      extra: deckName,
    );
  }
}

class _EmptyLibrary extends ConsumerStatefulWidget {
  const _EmptyLibrary();

  @override
  ConsumerState<_EmptyLibrary> createState() => _EmptyLibraryState();
}

class _EmptyLibraryState extends ConsumerState<_EmptyLibrary> {
  bool _seeding = false;

  Future<void> _trySampleDeck() async {
    setState(() => _seeding = true);
    final deck = await ref
        .read(decksControllerProvider.notifier)
        .seedSampleDeck();
    if (!mounted) return;
    setState(() => _seeding = false);
    // seedSampleDeck returns null on failure; the error is already surfaced by
    // the decksControllerProvider SnackBar listener in build().
    if (deck == null) return;
    // Land the user on real content rather than back on this empty state.
    context.pushNamed(
      AppRoutes.deckOverviewName,
      pathParameters: {'deckId': deck.id},
      extra: deck.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No decks yet.\nCreate your first deck to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _seeding ? null : _trySampleDeck,
              icon: _seeding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_stories_outlined),
              label: Text(
                _seeding ? 'Adding sample deck…' : 'Try a sample deck',
              ),
            ),
          ],
        ),
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
