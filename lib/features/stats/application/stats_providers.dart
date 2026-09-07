import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/stale_first.dart';
import '../../../core/local_db/local_db_providers.dart';
import '../../courses/application/course_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../data/cache_first_stats_repository.dart';
import '../data/local_stats_store.dart';
import '../data/supabase_stats_repository.dart';
import '../../courses/domain/course.dart';
import '../domain/activity_feed.dart';
import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';
import '../domain/course_summary.dart';
import '../domain/daily_activity.dart';
import '../domain/history_log.dart';
import '../domain/overall_mastery.dart';
import '../domain/stats_repository.dart';
import '../domain/study_metrics.dart';

/// The APIs behind the future Mastery / Stats screen (engine-v2-spec §6).
/// Providers + repository methods only — no widgets in Engine V2.

/// The live repository persists successful Supabase session reads into the
/// SQLite mirror. The source notifiers below serve that mirror first and then
/// refresh it in the background. Tests override this with a fake.
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return CacheFirstStatsRepository(
    SupabaseStatsRepository(Supabase.instance.client),
    ref.watch(localStatsStoreProvider),
  );
});

/// The bound on every stats read (milestone E1). These are read-only and never
/// on the study path, but an unreachable host must not leave an uncached
/// Dashboard, History, or metrics section spinning. Overridden short in tests.
final statsLoadTimeoutProvider = Provider<Duration>(
  (ref) => kRevalidateTimeout,
);

/// The single app-wide, card-weighted mastery % (0–100). Pure derivation of
/// [decksProvider] — which already falls back to the local mirror (or an empty
/// list) when there is no connectivity and no database, so this degrades
/// cleanly with `appDatabaseProvider` null.
final overallMasteryProvider = FutureProvider<int>((ref) async {
  final decks = await ref.watch(decksProvider.future);
  return overallMasteryPercent(decks);
});

/// The most recently completed study sessions, newest first. The shared
/// completed-session data-access point: the Mastery tab's activity feed reads it
/// through [recentActivityProvider], and Milestone D's session metrics will read
/// it directly.
final recentCompletedSessionsProvider =
    AsyncNotifierProvider<
      RecentCompletedSessionsNotifier,
      List<CompletedSessionActivity>
    >(RecentCompletedSessionsNotifier.new);

class RecentCompletedSessionsNotifier
    extends AsyncNotifier<List<CompletedSessionActivity>> {
  @override
  Future<List<CompletedSessionActivity>> build() async {
    final local = ref.watch(localStatsStoreProvider);
    final repository = ref.watch(statsRepositoryProvider);
    final timeout = ref.watch(statsLoadTimeoutProvider);
    final sessions = await local.recentCompletedSessions(activityFeedLimit);
    final cache = await local.cacheState(recentSessionsCacheKey);
    if (cache.hasCachedData || sessions.isNotEmpty) {
      unawaited(Future<void>(() => _refresh()));
      return sessions;
    }
    final fresh = await repository.fetchRecentCompletedSessions().timeout(
      timeout,
    );
    ref.invalidate(recentSessionCacheStateProvider);
    return fresh;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref
          .read(statsRepositoryProvider)
          .fetchRecentCompletedSessions()
          .timeout(ref.read(statsLoadTimeoutProvider));
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      ref.invalidate(recentSessionCacheStateProvider);
    } catch (_) {
      // Cached data remains visible when background refresh fails.
    }
  }
}

final recentSessionCacheStateProvider = FutureProvider(
  (ref) =>
      ref.watch(localStatsStoreProvider).cacheState(recentSessionsCacheKey),
);

/// The Mastery tab's recent-activity feed (milestone C): completed sessions,
/// created decks and created courses, merged newest-first and capped at
/// [activityFeedLimit]. A pure fold over data the app already holds —
/// [recentCompletedSessionsProvider], [decksProvider] and [coursesProvider],
/// each of which already degrades cleanly when offline.
final recentActivityProvider = FutureProvider<List<ActivityItem>>((ref) async {
  final sessions = await ref.watch(recentCompletedSessionsProvider.future);
  final decks = await ref.watch(decksProvider.future);
  final List<Course> courses = await ref.watch(coursesProvider.future);
  return buildActivityFeed(sessions: sessions, decks: decks, courses: courses);
});

/// "Times fully cleared" per deck (engine-v2-spec §4.3), keyed by deck id.
final deckRunThroughsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref
      .watch(statsRepositoryProvider)
      .fetchDeckRunThroughs()
      .timeout(ref.watch(statsLoadTimeoutProvider));
});

/// Every completed study session (newest first, capped) — the shared history
/// access point for the Profile tab's streaks and study-volume metrics
/// (milestone D). The current-streak provider reads it too, so a Profile load
/// makes one session fetch, not two.
final completedSessionsProvider =
    AsyncNotifierProvider<CompletedSessionsNotifier, List<CompletedSession>>(
      CompletedSessionsNotifier.new,
    );

class CompletedSessionsNotifier extends AsyncNotifier<List<CompletedSession>> {
  @override
  Future<List<CompletedSession>> build() async {
    final local = ref.watch(localStatsStoreProvider);
    final repository = ref.watch(statsRepositoryProvider);
    final timeout = ref.watch(statsLoadTimeoutProvider);
    final sessions = await local.completedSessions(completedSessionsLimit);
    final cache = await local.cacheState(completedSessionsCacheKey);
    if (cache.hasCachedData || sessions.isNotEmpty) {
      unawaited(Future<void>(() => _refresh()));
      return sessions;
    }
    final fresh = await repository.fetchCompletedSessions().timeout(timeout);
    ref.invalidate(completedSessionCacheStateProvider);
    return fresh;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await ref
          .read(statsRepositoryProvider)
          .fetchCompletedSessions()
          .timeout(ref.read(statsLoadTimeoutProvider));
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      ref.invalidate(completedSessionCacheStateProvider);
    } catch (_) {
      // Cached data remains visible when background refresh fails.
    }
  }
}

final completedSessionCacheStateProvider = FutureProvider(
  (ref) =>
      ref.watch(localStatsStoreProvider).cacheState(completedSessionsCacheKey),
);

/// The Profile tab's "Study habits" block (milestone D): current + longest
/// streak, lifetime session/card/time totals and this-week rollups, folded from
/// [completedSessionsProvider]. Pure derivation — see [buildStudyMetrics].
final studyMetricsProvider = FutureProvider<StudyMetrics>((ref) async {
  final sessions = await ref.watch(completedSessionsProvider.future);
  return buildStudyMetrics(sessions: sessions);
});

/// Per-course rollups. Pure derivation of [coursesProvider] + [decksProvider],
/// both of which already degrade cleanly when offline.
final courseSummariesProvider = FutureProvider<List<CourseSummary>>((
  ref,
) async {
  final courses = await ref.watch(coursesProvider.future);
  final decks = await ref.watch(decksProvider.future);
  return rollUpCourses(courses, decks);
});

/// The History tab's session log (ui-spec-v4 section 4): the recent completed
/// sessions from [recentCompletedSessionsProvider], each resolved to its deck
/// name, course label and accent. A pure join -- see [buildHistoryLog].
final historyLogProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final sessions = await ref.watch(recentCompletedSessionsProvider.future);
  final decks = await ref.watch(decksProvider.future);
  final courses = await ref.watch(coursesProvider.future);
  return buildHistoryLog(sessions: sessions, decks: decks, courses: courses);
});

/// The History tab's calendar heatmap data (ui-spec-v4 section 4): completed
/// sessions per local calendar day, folded from the full completed-session
/// history ([completedSessionsProvider]). See [buildDailyActivityCounts].
final dailyActivityProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final sessions = await ref.watch(completedSessionsProvider.future);
  return buildDailyActivityCounts(sessions);
});

/// Refreshes the actual History inputs. Derived providers rebuild as a result;
/// invalidating only them would keep a failed source future cached.
final retryHistorySourcesProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(recentCompletedSessionsProvider);
    ref.invalidate(completedSessionsProvider);
    ref.invalidate(decksProvider);
    ref.invalidate(coursesProvider);
  };
});
