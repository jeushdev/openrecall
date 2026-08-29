import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/mastery/course_rollup_strip.dart';
import '../../../ui/mastery/deck_completions_section.dart';
import '../../../ui/mastery/overall_mastery_card.dart';
import '../../../ui/mastery/troublemaker_section.dart';
import '../../decks/application/deck_providers.dart';
import '../application/stats_providers.dart';
import '../domain/deck_completion.dart';
import '../domain/troublemaker_severity.dart';

/// The Mastery tab (`/mastery`, ui-spec-v1 §6.3).
///
/// Four stacked sections, coarsest grouping to finest: the app-wide mastery
/// card, a horizontal strip of per-course rollups, the per-deck "completions"
/// list, and the cross-deck "troublemaker cards" list. Every value comes from
/// Engine V2's local aggregation providers — no query is written here, and the
/// two "by deck" lists just join a provider's deck-id-keyed data against
/// `decksProvider` for display names.
class MasteryTabScreen extends ConsumerWidget {
  const MasteryTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    final overall = ref.watch(overallMasteryProvider);
    final courses = ref.watch(courseSummariesProvider);
    final decks = ref.watch(decksProvider);
    final runThroughs = ref.watch(deckRunThroughsProvider);
    final troublemakers = ref.watch(troublemakersProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              'Mastery',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Overall mastery card.
            _AsyncSection(
              value: overall,
              onRetry: () => ref.invalidate(overallMasteryProvider),
              builder: (percent) => OverallMasteryCard(percent: percent),
            ),
            const SizedBox(height: 20),

            // Per-course rollups.
            _AsyncSection(
              value: courses,
              onRetry: () => ref.invalidate(courseSummariesProvider),
              builder: (list) => CourseRollupStrip(courses: list),
            ),
            const SizedBox(height: 24),

            // Deck completions — run-through counts joined to deck names.
            _AsyncSection2(
              a: runThroughs,
              b: decks,
              onRetry: () {
                ref.invalidate(deckRunThroughsProvider);
                ref.invalidate(decksProvider);
              },
              builder: (counts, deckList) => DeckCompletionsSection(
                completions: deckCompletions(counts, deckList),
              ),
            ),
            const SizedBox(height: 24),

            // Troublemaker cards — fail_count-ordered query joined to deck names.
            _AsyncSection2(
              a: troublemakers,
              b: decks,
              onRetry: () {
                ref.invalidate(troublemakersProvider);
                ref.invalidate(decksProvider);
              },
              builder: (cards, deckList) {
                final nameById = {
                  for (final deck in deckList) deck.id: deck.name,
                };
                return TroublemakerSection(
                  entries: [
                    for (final card in cards)
                      (
                        frontExcerpt: card.front,
                        deckName: nameById[card.deckId] ?? 'Unknown deck',
                        failCount: card.failCount,
                        severity: severityFor(card.failCount),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [builder] once [value] has data; a compact spinner while it loads and
/// a one-line retry affordance if it errors. Keeps each section independent so a
/// slow troublemaker query never blanks the whole screen.
class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const _SectionLoading(),
      error: (_, _) => _SectionError(onRetry: onRetry),
    );
  }
}

/// Two-provider variant of [_AsyncSection]: waits for both, surfaces one retry.
class _AsyncSection2<A, B> extends StatelessWidget {
  const _AsyncSection2({
    super.key,
    required this.a,
    required this.b,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<A> a;
  final AsyncValue<B> b;
  final VoidCallback onRetry;
  final Widget Function(A dataA, B dataB) builder;

  @override
  Widget build(BuildContext context) {
    if (a.hasError || b.hasError) return _SectionError(onRetry: onRetry);
    final dataA = a.value;
    final dataB = b.value;
    if (dataA == null || dataB == null) return const _SectionLoading();
    return builder(dataA, dataB);
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load this section.",
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
