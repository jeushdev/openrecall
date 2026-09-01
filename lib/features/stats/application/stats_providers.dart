import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../courses/application/course_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../data/cache_first_stats_repository.dart';
import '../data/supabase_stats_repository.dart';
import '../../courses/domain/course.dart';
import '../domain/activity_feed.dart';
import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';
import '../domain/course_summary.dart';
import '../domain/overall_mastery.dart';
import '../domain/stats_repository.dart';
import '../domain/study_metrics.dart';

/// The APIs behind the future Mastery / Stats screen (engine-v2-spec §6).
/// Providers + repository methods only — no widgets in Engine V2.

/// The live repository is the Supabase-backed one wrapped in the cache-first
/// layer: reads fall back to the local SQLite mirror. Tests override this with a
/// fake.
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return CacheFirstStatsRepository(
    SupabaseStatsRepository(Supabase.instance.client),
    ref.watch(localStatsStoreProvider),
  );
});

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
    FutureProvider<List<CompletedSessionActivity>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchRecentCompletedSessions();
});

/// The Mastery tab's recent-activity feed (milestone C): completed sessions,
/// created decks and created courses, merged newest-first and capped at
/// [activityFeedLimit]. A pure fold over data the app already holds —
/// [recentCompletedSessionsProvider], [decksProvider] and [coursesProvider],
/// each of which already degrades cleanly when offline.
final recentActivityProvider = FutureProvider<List<ActivityItem>>((ref) async {
  final sessions = await ref.watch(recentCompletedSessionsProvider.future);
  final decks = await ref.watch(decksProvider.future);
  final List<Course> courses = await ref.watch(coursesProvider.future);
  return buildActivityFeed(
    sessions: sessions,
    decks: decks,
    courses: courses,
  );
});

/// "Times fully cleared" per deck (engine-v2-spec §4.3), keyed by deck id.
final deckRunThroughsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchDeckRunThroughs();
});

/// Every completed study session (newest first, capped) — the shared history
/// access point for the Profile tab's streaks and study-volume metrics
/// (milestone D). The current-streak provider reads it too, so a Profile load
/// makes one session fetch, not two.
final completedSessionsProvider =
    FutureProvider<List<CompletedSession>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchCompletedSessions();
});

/// The Profile tab's "Study habits" block (milestone D): current + longest
/// streak, lifetime session/card/time totals and this-week rollups, folded from
/// [completedSessionsProvider]. Pure derivation — see [buildStudyMetrics].
final studyMetricsProvider = FutureProvider<StudyMetrics>((ref) async {
  final sessions = await ref.watch(completedSessionsProvider.future);
  return buildStudyMetrics(sessions: sessions);
});

/// Per-course rollups. Pure derivation of [coursesProvider] + [decksProvider],
/// both of which already degrade cleanly when offline.
final courseSummariesProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final courses = await ref.watch(coursesProvider.future);
  final decks = await ref.watch(decksProvider.future);
  return rollUpCourses(courses, decks);
});
