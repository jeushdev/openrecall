import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../courses/application/course_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/domain/study_mode.dart';
import '../../stats/application/stats_providers.dart';
import '../../stats/data/local_stats_store.dart';
import '../../stats/domain/active_session.dart';

/// The Home tab's data layer (ui-spec-v4-navigation §3). Every provider here is
/// a read-only join of things the app already holds plus the two new
/// `StatsRepository` queries; none of it is on the study path.

/// One card in Home's "Unfinished Sessions" strip: an `active` session, its
/// deck name, and how far through its queue it is.
class UnfinishedSession {
  const UnfinishedSession({
    required this.deckId,
    required this.deckName,
    required this.studyMode,
    required this.percentComplete,
  });

  final String deckId;
  final String deckName;
  final StudyMode studyMode;

  /// 0–100. Resuming re-queues this deck's still-unmastered cards in
  /// [studyMode] (the study route always runs until-mastered over the whole
  /// deck), so the figure is indicative, not a saved cursor.
  final int percentComplete;
}

/// The still-`active` sessions, newest first, each joined to its deck name.
/// Sessions whose deck is no longer in [decksProvider] (deleted, or not
/// downloaded offline) are dropped rather than shown nameless.
final activeSessionProgressProvider =
    AsyncNotifierProvider<
      ActiveSessionProgressNotifier,
      List<ActiveSessionProgress>
    >(ActiveSessionProgressNotifier.new);

class ActiveSessionProgressNotifier
    extends AsyncNotifier<List<ActiveSessionProgress>> {
  @override
  Future<List<ActiveSessionProgress>> build() async {
    final local = ref.watch(localStatsStoreProvider);
    final repository = ref.watch(statsRepositoryProvider);
    final timeout = ref.watch(statsLoadTimeoutProvider);
    final sessions = await local.activeSessions();
    final cache = await local.cacheState(activeSessionsCacheKey);
    if (cache.hasCachedData || sessions.isNotEmpty) {
      unawaited(Future<void>(() => _refresh()));
      return sessions;
    }
    final fresh = await repository.fetchActiveSessions().timeout(timeout);
    ref.invalidate(activeSessionCacheStateProvider);
    return fresh;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref
          .read(statsRepositoryProvider)
          .fetchActiveSessions()
          .timeout(ref.read(statsLoadTimeoutProvider));
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      ref.invalidate(activeSessionCacheStateProvider);
    } catch (_) {
      // Cached Dashboard data remains visible on refresh failure.
    }
  }
}

final activeSessionCacheStateProvider = FutureProvider(
  (ref) =>
      ref.watch(localStatsStoreProvider).cacheState(activeSessionsCacheKey),
);

final activeSessionsProvider = FutureProvider<List<UnfinishedSession>>((
  ref,
) async {
  final sessions = await ref.watch(activeSessionProgressProvider.future);
  if (sessions.isEmpty) return const [];
  final decks = await ref.watch(decksProvider.future);
  final nameById = {for (final d in decks) d.id: d.name};
  return [
    for (final s in sessions)
      if (nameById[s.deckId] != null)
        UnfinishedSession(
          deckId: s.deckId,
          deckName: nameById[s.deckId]!,
          studyMode: s.studyMode,
          percentComplete: s.percentComplete,
        ),
  ];
});

/// Completed-session count per deck id — the ordering key for
/// [mostReviewedDecksProvider]. Its own provider so a Home rebuild fetches it
/// once.
final sessionCountsByDeckProvider =
    AsyncNotifierProvider<SessionCountsByDeckNotifier, Map<String, int>>(
      SessionCountsByDeckNotifier.new,
    );

class SessionCountsByDeckNotifier extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final local = ref.watch(localStatsStoreProvider);
    final repository = ref.watch(statsRepositoryProvider);
    final timeout = ref.watch(statsLoadTimeoutProvider);
    final counts = await local.sessionCountsByDeck();
    final cache = await local.cacheState(completedSessionsCacheKey);
    if (cache.hasCachedData || counts.isNotEmpty) {
      unawaited(Future<void>(() => _refresh()));
      return counts;
    }
    final fresh = await repository.fetchSessionCountsByDeck().timeout(timeout);
    ref.invalidate(completedSessionCacheStateProvider);
    return fresh;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref
          .read(statsRepositoryProvider)
          .fetchSessionCountsByDeck()
          .timeout(ref.read(statsLoadTimeoutProvider));
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      ref.invalidate(completedSessionCacheStateProvider);
    } catch (_) {
      // Cached Dashboard data remains visible on refresh failure.
    }
  }
}

/// One card in Home's "Most Reviewed Decks" stack.
class MostReviewedDeck {
  const MostReviewedDeck({
    required this.deckId,
    required this.deckName,
    required this.cardCount,
    required this.courseName,
    required this.accentColor,
    required this.sessionCount,
  });

  final String deckId;
  final String deckName;
  final int cardCount;

  /// The deck's course name, shown as the card's "code" line, or `null` for a
  /// deck with no resolvable course (offline mirror without the course row).
  final String? courseName;

  /// The course's accent key (`slate` fallback), mapped to colour via
  /// `AppTokens.accent`.
  final String accentColor;
  final int sessionCount;
}

/// How many decks Home's stack shows at most.
const int mostReviewedDecksLimit = 6;

/// Decks ordered by completed-session count (descending), ties broken by most
/// recently studied, capped at [mostReviewedDecksLimit]. Decks never studied
/// are eligible only to fill the tail. A pure join of [decksProvider],
/// [coursesProvider] and [sessionCountsByDeckProvider].
final mostReviewedDecksProvider = FutureProvider<List<MostReviewedDeck>>((
  ref,
) async {
  final counts = await ref.watch(sessionCountsByDeckProvider.future);
  final decks = await ref.watch(decksProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  final courseById = {for (final c in courses) c.id: c};

  final ranked = [...decks]
    ..sort((a, b) {
      final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      if (byCount != 0) return byCount;
      final at = a.lastStudiedAt;
      final bt = b.lastStudiedAt;
      if (at == null && bt == null) return a.name.compareTo(b.name);
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

  return [
    for (final d in ranked.take(mostReviewedDecksLimit))
      MostReviewedDeck(
        deckId: d.id,
        deckName: d.name,
        cardCount: d.totalCards,
        courseName: courseById[d.courseId]?.name,
        accentColor: courseById[d.courseId]?.accentColor ?? 'slate',
        sessionCount: counts[d.id] ?? 0,
      ),
  ];
});
