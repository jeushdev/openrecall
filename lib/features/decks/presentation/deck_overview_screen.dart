import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../application/deck_providers.dart';
import '../domain/deck_overview_stats.dart';
import '../domain/study_mode.dart';
import 'widgets/mastery_bar.dart';
import 'widgets/mode_selector.dart';
import 'widgets/session_length_selector.dart';
import 'widgets/troublemaker_list.dart';

/// The Deck Overview (spec §4): a deck's stats, the mode selector, the
/// session-length toggle, Troublemaker cards, and the way back into the Deck
/// Creator to add more cards.
///
/// Reached by tapping a deck in the Library. Starting a session is milestone 6 —
/// mode buttons here only reflect what the deck supports.
class DeckOverviewScreen extends ConsumerStatefulWidget {
  const DeckOverviewScreen({super.key, required this.deckId, this.deckName});

  final String deckId;
  final String? deckName;

  @override
  ConsumerState<DeckOverviewScreen> createState() => _DeckOverviewScreenState();
}

class _DeckOverviewScreenState extends ConsumerState<DeckOverviewScreen> {
  SessionLengthMode _lengthMode = SessionLengthMode.untilMastered;
  int? _cap = sessionCapPresets.first;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(deckCardsProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.deckName ?? 'Deck')),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadError(
          onRetry: () => ref.invalidate(deckCardsProvider(widget.deckId)),
        ),
        data: (list) => _Body(
          stats: DeckOverviewStats.fromCards(list),
          lengthMode: _lengthMode,
          cap: _cap,
          onLengthModeChanged: (m) => setState(() => _lengthMode = m),
          onCapChanged: (c) => setState(() => _cap = c),
          onStartMode: _startMode,
          onAddCards: _openCreator,
        ),
      ),
    );
  }

  void _startMode(StudyMode mode) {
    // Sessions arrive in milestone 6 — for now the button just acknowledges.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${mode.label} sessions arrive in the next update.')),
      );
  }

  void _openCreator() {
    context.pushNamed(
      AppRoutes.deckCreatorName,
      pathParameters: {'deckId': widget.deckId},
      extra: widget.deckName,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.stats,
    required this.lengthMode,
    required this.cap,
    required this.onLengthModeChanged,
    required this.onCapChanged,
    required this.onStartMode,
    required this.onAddCards,
  });

  final DeckOverviewStats stats;
  final SessionLengthMode lengthMode;
  final int? cap;
  final ValueChanged<SessionLengthMode> onLengthModeChanged;
  final ValueChanged<int?> onCapChanged;
  final ValueChanged<StudyMode> onStartMode;
  final VoidCallback onAddCards;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stats.isEmpty)
          const _EmptyDeck()
        else ...[
          _StatsCard(stats: stats),
          const SizedBox(height: 16),
          if (stats.allCaughtUp) ...[
            const _CaughtUpBanner(),
            const SizedBox(height: 16),
          ],
          ModeSelector(available: stats.modes, onStart: onStartMode),
          const SizedBox(height: 16),
          SessionLengthSelector(
            mode: lengthMode,
            cap: cap,
            onModeChanged: onLengthModeChanged,
            onCapChanged: onCapChanged,
          ),
          const SizedBox(height: 24),
          TroublemakerList(cards: stats.troublemakers),
          const SizedBox(height: 24),
        ],
        OutlinedButton.icon(
          onPressed: onAddCards,
          icon: const Icon(Icons.add),
          label: const Text('Add cards'),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final DeckOverviewStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MasteryBar(percent: stats.masteryPercent),
            const SizedBox(height: 12),
            Text(
              '${stats.totalCards} cards  ·  ${stats.dueCards} due',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${stats.withKeyword} with a keyword  ·  '
              '${stats.multiLine} multi-line',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaughtUpBanner extends StatelessWidget {
  const _CaughtUpBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're all caught up — nothing is due right now.",
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(8, 24, 8, 24),
      child: Text(
        'This deck has no cards yet. Add some to start studying.',
        textAlign: TextAlign.center,
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
          const Text("Couldn't load this deck."),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
