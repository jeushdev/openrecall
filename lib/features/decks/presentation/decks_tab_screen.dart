import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_tokens.dart';
import '../application/decks_tab_view.dart';
import 'deck_segment.dart';
import 'widgets/deck_grid.dart';
import 'widgets/deck_segmented_control.dart';

/// The Decks tab (`/decks`, ui-spec-v1 §6.1) — the app's home screen.
///
/// A "Decks" header, a Due / All segmented control with its consequence-signalling
/// caption, then a 2-column grid of square deck tiles. Switching segments only
/// swaps each tile's trailing badge; the deck list and its order are unaffected.
///
/// The grid reads real decks from [decksTabViewProvider] (cache-first, so it
/// degrades to the local mirror / an empty list offline). Tapping a tile pushes
/// `/study/:deckId?scope=due|all` with the active segment's scope.
class DecksTabScreen extends ConsumerStatefulWidget {
  const DecksTabScreen({super.key});

  @override
  ConsumerState<DecksTabScreen> createState() => _DecksTabScreenState();
}

class _DecksTabScreenState extends ConsumerState<DecksTabScreen> {
  DeckSegment _segment = DeckSegment.due;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final decks = ref.watch(decksTabViewProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Decks',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DeckSegmentedControl(
                value: _segment,
                onChanged: (segment) => setState(() => _segment = segment),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Due reviews what's due today · All studies the whole deck, "
                "including cards you've mastered.",
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: tokens.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: decks.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => _DecksError(
                  onRetry: () => refreshDecksTab(ref),
                ),
                data: (list) => DeckGrid(decks: list, segment: _segment),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the deck list can't be loaded (no connection and nothing mirrored
/// locally). The trailing Create tile still lives inside [DeckGrid] for the
/// empty-but-loaded case; this is only the hard-failure state.
class _DecksError extends StatelessWidget {
  const _DecksError({required this.onRetry});

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
              "Couldn't load your decks.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.push(AppRoutes.deckCreatorPath),
              child: const Text('Create a deck'),
            ),
          ],
        ),
      ),
    );
  }
}
