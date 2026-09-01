import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_feed.dart';
import '../domain/completed_session_activity.dart';
import '../domain/stats_repository.dart';

/// The only class in the stats feature that talks to Supabase Postgres directly.
/// RLS scopes every query to the signed-in user — `study_sessions` through its
/// `user_id` — so no owner filter is needed here.
class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  }) async {
    final rows = await _client
        .from('study_sessions')
        .select('deck_id, completed_at, mastery_delta')
        .eq('status', 'completed')
        .not('completed_at', 'is', null)
        .order('completed_at', ascending: false)
        .limit(limit);
    return [
      for (final row in rows)
        CompletedSessionActivity(
          deckId: row['deck_id'] as String,
          completedAt: DateTime.parse(row['completed_at'] as String),
          masteryDelta: row['mastery_delta'] as int?,
        ),
    ];
  }

  @override
  Future<Map<String, int>> fetchDeckRunThroughs() async {
    // supabase-dart has no GROUP BY, so pull the one column and fold. Only
    // completed whole-deck sessions count (engine-v2-spec §4.3).
    final rows = await _client
        .from('study_sessions')
        .select('deck_id')
        .eq('card_scope', 'all')
        .eq('status', 'completed');
    final counts = <String, int>{};
    for (final row in rows) {
      final deckId = row['deck_id'] as String;
      counts[deckId] = (counts[deckId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<DateTime>> fetchCompletedSessionStarts() async {
    // Only `started_at` is needed — the streak is a pure calendar-day fold over
    // these. Capped at 500 rows: well over a year of daily study, and the fold
    // never needs more than the current unbroken run anyway.
    final rows = await _client
        .from('study_sessions')
        .select('started_at')
        .eq('status', 'completed')
        .order('started_at', ascending: false)
        .limit(500);
    return [
      for (final row in rows) DateTime.parse(row['started_at'] as String),
    ];
  }
}
