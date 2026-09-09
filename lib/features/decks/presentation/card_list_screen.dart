import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_tokens.dart';
import '../application/deck_providers.dart';
import '../application/offline_runtime_providers.dart';
import '../data/cache_first_deck_repository.dart';
import '../application/pending_deletions.dart';
import '../domain/deck.dart';
import 'widgets/card_list_item.dart';
import 'widgets/edit_card_dialog.dart';

/// Card list (`/deck/:deckId/cards`, ui-spec-v2 §6.5) — view / edit / delete the
/// cards in one deck.
///
/// A top-level route outside the shell (`app_router.dart`), so the bottom nav bar
/// is absent. Reads [deckCardsProvider]; each row opens [EditCardDialog], which
/// drives the update / delete through [DecksController] and refreshes this list
/// via the provider invalidation the controller already does. The empty state
/// links to the Import screen (§6.4).
class CardListScreen extends ConsumerWidget {
  const CardListScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(offlineDeckObservationProvider(deckId));
    ref.listen(decksControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

    final tokens = Theme.of(context).extension<AppTokens>()!;
    final deckName = _deckName(ref.watch(decksProvider));
    final cards = ref.watch(deckCardsProvider(deckId));

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(title: Text(deckName ?? 'Cards')),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => error is DeckUnavailableOfflineException
            ? const _UnavailableOffline()
            : _CardsError(
                onRetry: () => ref.invalidate(deckCardsProvider(deckId)),
              ),
        data: (all) {
          // Subtract cards whose deletion is still in flight (milestone R1).
          final pendingCards = ref.watch(
            pendingDeletionsProvider.select((p) => p.cardIds),
          );
          final list = pendingCards.isEmpty
              ? all
              : all.where((c) => !pendingCards.contains(c.id)).toList();
          if (list.isEmpty) return _EmptyCards(deckId: deckId);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: tokens.borderHairline,
            ),
            itemBuilder: (context, i) {
              final card = list[i];
              return CardListItem(
                card: card,
                onTap: () =>
                    showEditCardDialog(context, card: card, deckId: deckId),
              );
            },
          );
        },
      ),
    );
  }

  String? _deckName(AsyncValue<List<DeckSummary>> decks) {
    for (final deck in decks.asData?.value ?? const <DeckSummary>[]) {
      if (deck.id == deckId) return deck.name;
    }
    return null;
  }
}

/// Shown when the deck has no cards yet — a call to action into the Import
/// screen (ui-spec-v2 §6.5).
class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No cards yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pushNamed(
                AppRoutes.importCardsName,
                pathParameters: {'deckId': deckId},
              ),
              child: const Text('Add cards'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsError extends StatelessWidget {
  const _CardsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load this deck's cards.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _UnavailableOffline extends StatelessWidget {
  const _UnavailableOffline();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "This deck isn't available offline. Connect to the internet to download it.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: tokens.textPrimary),
        ),
      ),
    );
  }
}
