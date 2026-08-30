import 'package:flutter/material.dart';

import '../../../decks/domain/study_mode.dart';
import '../../domain/session_outcome.dart';

/// The Session Summary (spec §7), shown when a session reaches
/// [SessionPhase.completed]: the deck's mastery % delta for the run, the
/// lightweight recall metrics framed for the session's mode, a one-tap
/// "Drill parked cards now" when the run left cards parked, and "Done" back to
/// the Deck Overview.
class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({
    super.key,
    required this.mode,
    required this.deckName,
    required this.outcome,
    required this.hasParked,
    required this.onDrillParked,
    required this.onDone,
  });

  final StudyMode mode;
  final String? deckName;
  final SessionOutcome outcome;

  /// Whether the finished session left any card parked — gates the drill button.
  final bool hasParked;

  final VoidCallback onDrillParked;
  final VoidCallback onDone;

  /// The mode-specific phrasing for the "recalled on the first try" metric
  /// (spec §7 — recall metrics for the session's own mode).
  String get _firstTryLabel => switch (mode) {
        StudyMode.flip => 'recalled on the first flip',
        StudyMode.cloze => 'typed right on the first try',
        StudyMode.feynman => 'recalled on the first pass',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final delta = outcome.masteryDelta;
    final sign = delta > 0 ? '+' : '';

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDone();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(deckName ?? 'Session complete')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deck mastery',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$sign$delta%',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${outcome.masteryPercentBefore}% → '
                      '${outcome.masteryPercentAfter}%',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This session',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 12),
                    _MetricLine(
                      label: 'Cards studied',
                      value: '${outcome.cardsStudied}',
                    ),
                    _MetricLine(
                      label: 'Mastered',
                      value: '${outcome.mastered}',
                    ),
                    _MetricLine(
                      label: 'Parked',
                      value: '${outcome.parked}',
                    ),
                    _MetricLine(
                      label: _capitalize(_firstTryLabel),
                      value: '${outcome.firstTryMastered}',
                    ),
                    _MetricLine(
                      label: outcome.requeues == 1 ? 'Miss' : 'Misses',
                      value: '${outcome.requeues}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (hasParked) ...[
              FilledButton.icon(
                onPressed: onDrillParked,
                icon: const Icon(Icons.bolt),
                label: const Text('Drill parked cards now'),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
