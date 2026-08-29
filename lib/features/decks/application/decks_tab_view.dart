import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../courses/application/course_providers.dart';
import '../../courses/domain/course.dart';
import '../../stats/application/stats_providers.dart';
import '../domain/deck.dart';
import 'deck_providers.dart';

/// One deck as the Decks-tab grid needs it (ui-spec-v1 §6.1): the fields the
/// tile shows, with the parent course's accent already resolved to its named
/// key and the "times cleared" run-through count already looked up.
@immutable
class DeckTileView {
  const DeckTileView({
    required this.id,
    required this.name,
    required this.dueCount,
    required this.clearedCount,
    required this.accentKey,
  });

  /// The real `decks.id` — handed straight to `/study/:deckId`.
  final String id;
  final String name;

  /// Cards below Mastered — drives the **Due** segment badge.
  final int dueCount;

  /// Completed `card_scope: 'all'` run-throughs — drives the **All** badge (§7).
  final int clearedCount;

  /// One of the eight `courses.accent_color` keys, resolved through the deck's
  /// parent course. Falls back to `slate` when the course is unknown or its
  /// data hasn't loaded yet.
  final String accentKey;
}

/// How long the Decks tab waits on the deck-list fetch before giving up. The tab
/// is the app's home screen — it must not sit on a spinner forever because
/// Supabase is slow or asleep (same reasoning as the study screen's bound,
/// ui-spec-v1 §2). Overridden short in tests.
final decksLoadTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 6));

/// The deck list for the tab, bounded by [decksLoadTimeoutProvider]. Separate
/// from the app-wide [decksProvider] (which the Mastery tab and stats layer also
/// read) so the timeout only applies here.
final _tabDecksProvider = FutureProvider<List<DeckSummary>>((ref) async {
  final timeout = ref.watch(decksLoadTimeoutProvider);
  return ref.watch(deckRepositoryProvider).fetchDecks().timeout(timeout);
});

/// The Decks-tab grid model.
///
/// Driven by [_tabDecksProvider] — its loading / error / empty state is the
/// screen's state. The parent-course accent ([coursesProvider]) and per-deck
/// run-through count ([deckRunThroughsProvider]) are best-effort enrichment:
/// while they load or if they fail, tiles fall back to `slate` and a zero count
/// rather than blocking or erroring the whole grid.
final decksTabViewProvider = Provider<AsyncValue<List<DeckTileView>>>((ref) {
  final decksAsync = ref.watch(_tabDecksProvider);
  final courses =
      ref.watch(coursesProvider).asData?.value ?? const <Course>[];
  final runThroughs = ref.watch(deckRunThroughsProvider).asData?.value ??
      const <String, int>{};

  final accentByCourse = {for (final c in courses) c.id: c.accentColor};

  return decksAsync.whenData(
    (decks) => [
      for (final d in decks)
        DeckTileView(
          id: d.id,
          name: d.name,
          dueCount: d.dueCards,
          clearedCount: runThroughs[d.id] ?? 0,
          accentKey: accentByCourse[d.courseId] ?? 'slate',
        ),
    ],
  );
});

/// Re-runs the deck-list fetch (Retry on the error state).
void refreshDecksTab(WidgetRef ref) {
  ref.invalidate(_tabDecksProvider);
  ref.invalidate(decksProvider);
}
