import 'activity_feed.dart';
import 'completed_session.dart';
import 'completed_session_activity.dart';

/// The app's window onto the read-only, cross-deck aggregations that feed the
/// Mastery / Stats screen (engine-v2-spec §6).
///
/// Only the aggregations that need their own query live here. Overall mastery %
/// and per-course rollups are pure functions over the deck / course lists the
/// app already holds — see `overall_mastery.dart` / `course_summary.dart` — and
/// never reach a repository.
///
/// Every method is read-only and never blocks a study interaction. Offline they
/// fall back to the local SQLite mirror and may return partial results (only
/// downloaded decks / locally recorded sessions).
abstract interface class StatsRepository {
  /// The most recently `completed` study sessions, newest first, capped at
  /// [limit] — the completed-session source for the Mastery tab's activity feed
  /// (milestone C) and, later, Milestone D's session metrics.
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  });

  /// "Times fully cleared" per deck (engine-v2-spec §4.3): for each deck, the
  /// count of `completed` sessions whose `card_scope` was `all`. Decks that have
  /// never been cleared this way are absent from the map.
  Future<Map<String, int>> fetchDeckRunThroughs();

  /// Every `completed` study session, most-recent first, capped at [limit] — the
  /// raw input for the Profile tab's streaks and study-volume metrics
  /// (offline-and-ux milestone D). Carries just the timestamps and the stamped
  /// card count. Offline this returns only sessions recorded on this device.
  Future<List<CompletedSession>> fetchCompletedSessions({
    int limit = completedSessionsLimit,
  });
}
