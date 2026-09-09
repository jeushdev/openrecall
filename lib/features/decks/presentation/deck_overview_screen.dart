import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../routing/app_routes.dart';
import '../../study/application/session_controller.dart';
import '../../study/presentation/study_session_args.dart';
import '../application/deck_providers.dart';
import '../application/offline_providers.dart';
import '../data/cache_first_deck_repository.dart';
import '../domain/deck_overview_stats.dart';
import '../domain/study_mode.dart';
import 'widgets/mastery_bar.dart';
import 'widgets/mode_selector.dart';
import 'widgets/offline_toggle.dart';
import 'widgets/session_length_selector.dart';

/// The Deck Overview (spec §4): a deck's stats, the mode selector, the
/// session-length toggle, and the way back into the Deck Creator to add more
/// cards.
///
/// Reached by tapping a deck in the Library. Every mode the deck supports
/// starts a session (spec §5A–§5D). A "Resume session" button appears while a
/// session for this deck is live in memory.
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
    final session = ref.watch(sessionControllerProvider).value;
    final canResume =
        session != null &&
        session.deckId == widget.deckId &&
        !session.isComplete;
    final hasCards = cards.value?.isNotEmpty ?? false;

    final pinned =
        ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};
    final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
    // Updating a local mirror copy is meaningless with no mirror (web,
    // spec-web-mvp §5.3).
    final canUpdateOffline =
        !kIsWeb && pinned.contains(widget.deckId) && online;

    ref.listen(decksControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckName ?? 'Deck'),
        actions: [
          if (hasCards)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'reset':
                    _resetMastery();
                  case 'update-offline':
                    _updateOfflineCopy();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Text('Reset mastery'),
                ),
                if (canUpdateOffline)
                  const PopupMenuItem(
                    value: 'update-offline',
                    child: Text('Update offline copy'),
                  ),
              ],
            ),
        ],
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => err is DeckUnavailableOfflineException
            ? const _UnavailableOffline()
            : _LoadError(
                onRetry: () => ref.invalidate(deckCardsProvider(widget.deckId)),
              ),
        data: (list) => _Body(
          deckId: widget.deckId,
          deckName: widget.deckName,
          stats: DeckOverviewStats.fromCards(list),
          lengthMode: _lengthMode,
          cap: _cap,
          canResume: canResume,
          onResume: _resumeSession,
          onLengthModeChanged: (m) => setState(() => _lengthMode = m),
          onCapChanged: (c) => setState(() => _cap = c),
          onStartMode: _startMode,
          onAddCards: _openCreator,
          onResetMastery: _resetMastery,
        ),
      ),
    );
  }

  void _startMode(StudyMode mode) {
    context.pushNamed(
      AppRoutes.studySessionName,
      pathParameters: {'deckId': widget.deckId},
      extra: StudySessionArgs(
        deckId: widget.deckId,
        deckName: widget.deckName,
        mode: mode,
        lengthMode: _lengthMode,
        cap: _lengthMode == SessionLengthMode.capped ? _cap : null,
      ),
    );
  }

  void _resumeSession() {
    final session = ref.read(sessionControllerProvider).value?.session;
    if (session == null) return;
    context.pushNamed(
      AppRoutes.studySessionName,
      pathParameters: {'deckId': widget.deckId},
      extra: StudySessionArgs(
        deckId: widget.deckId,
        deckName: widget.deckName,
        mode: session.studyMode,
        lengthMode: session.lengthMode,
        cap: session.cappedLength,
      ),
    );
  }

  void _openCreator() {
    context.pushNamed(
      AppRoutes.deckCreatorName,
      pathParameters: {'deckId': widget.deckId},
      extra: widget.deckName,
    );
  }

  Future<void> _updateOfflineCopy() async {
    await ref
        .read(offlineControllerProvider.notifier)
        .updateOfflineCopy(widget.deckId);
    if (!mounted) return;
    if (!ref.read(offlineControllerProvider).hasError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Offline copy updated')));
    }
    // The error path surfaces via the OfflineToggle's own ref.listen.
  }

  Future<void> _resetMastery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset mastery?'),
        content: const Text(
          'Every card in this deck goes back to Unfamiliar and becomes due '
          'again. Card content and lifetime stats are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(decksControllerProvider.notifier)
        .resetDeckMastery(widget.deckId);
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.deckId,
    required this.deckName,
    required this.stats,
    required this.lengthMode,
    required this.cap,
    required this.canResume,
    required this.onResume,
    required this.onLengthModeChanged,
    required this.onCapChanged,
    required this.onStartMode,
    required this.onAddCards,
    required this.onResetMastery,
  });

  final String deckId;
  final String? deckName;
  final DeckOverviewStats stats;
  final SessionLengthMode lengthMode;
  final int? cap;
  final bool canResume;
  final VoidCallback onResume;
  final ValueChanged<SessionLengthMode> onLengthModeChanged;
  final ValueChanged<int?> onCapChanged;
  final ValueChanged<StudyMode> onStartMode;
  final VoidCallback onAddCards;
  final VoidCallback onResetMastery;

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
          if (canResume) ...[
            FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume session'),
            ),
            const SizedBox(height: 16),
          ],
          if (stats.allCaughtUp) ...[
            _CaughtUpBanner(onRestudy: onResetMastery),
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
          OfflineToggle(deckId: deckId, deckName: deckName),
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
  const _CaughtUpBanner({required this.onRestudy});

  final VoidCallback onRestudy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onRestudy,
                icon: const Icon(Icons.refresh),
                label: const Text('Restudy deck'),
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

class _UnavailableOffline extends StatelessWidget {
  const _UnavailableOffline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              "This deck isn't available offline.",
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to the internet to open it or pin it for offline study.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
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
          const Text("Couldn't load this deck."),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
