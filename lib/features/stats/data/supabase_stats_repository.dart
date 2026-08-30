import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/stats_repository.dart';
import '../domain/troublemaker_card.dart';

/// The only class in the stats feature that talks to Supabase Postgres directly.
/// RLS scopes every query to the signed-in user — `cards` through its join to
/// `decks`, `study_sessions` through its `user_id` — so no owner filter is
/// needed here.
class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TroublemakerCard>> fetchTroublemakers({
    int limit = appWideTroublemakerLimit,
  }) async {
    // A separate, lean query — deliberately not an expansion of the Deck
    // Library's deck select (engine-v2-spec §6).
    final rows = await _client
        .from('cards')
        .select('id, deck_id, front, back, fail_count')
        .order('fail_count', ascending: false)
        .limit(limit);
    return rows.map(TroublemakerCard.fromJson).toList();
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
