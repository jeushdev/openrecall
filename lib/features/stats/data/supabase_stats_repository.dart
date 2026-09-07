import 'package:supabase_flutter/supabase_flutter.dart';

import '../../decks/domain/card.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';
import '../domain/active_session.dart';
import '../domain/activity_feed.dart';
import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';
import '../domain/stats_repository.dart';

/// The only class in the stats feature that talks to Supabase Postgres directly.
/// RLS scopes every query to the signed-in user — `study_sessions` through its
/// `user_id` — so no owner filter is needed here.
class SupabaseStatsRepository implements StatsRepository {
  SupabaseStatsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> _completedRows(
    int limit, {
    required String orderBy,
  }) async {
    const pageSize = 200;
    final result = <Map<String, dynamic>>[];
    while (result.length < limit) {
      final remaining = limit - result.length;
      final take = remaining < pageSize ? remaining : pageSize;
      final page = await _client
          .from('study_sessions')
          .select(
            'id, deck_id, study_mode, length_mode, capped_length, '
            'card_scope, mastery_delta, cards_reviewed, started_at, '
            'completed_at',
          )
          .eq('status', 'completed')
          .not('completed_at', 'is', null)
          .order(orderBy, ascending: false)
          .range(result.length, result.length + take - 1);
      result.addAll(page.cast<Map<String, dynamic>>());
      if (page.length < take) break;
    }
    return result;
  }

  @override
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  }) async {
    final rows = await _completedRows(limit, orderBy: 'completed_at');
    return [
      for (final row in rows)
        CompletedSessionActivity(
          sessionId: row['id'] as String,
          deckId: row['deck_id'] as String,
          startedAt: DateTime.parse(row['started_at'] as String),
          completedAt: DateTime.parse(row['completed_at'] as String),
          masteryDelta: row['mastery_delta'] as int?,
          studyMode: studyModeFromDb(row['study_mode'] as String),
          cardsReviewed: row['cards_reviewed'] as int?,
          lengthMode: sessionLengthModeFromDb(row['length_mode'] as String),
          cappedLength: row['capped_length'] as int?,
          cardScope: row['card_scope'] == null
              ? CardScope.due
              : cardScopeFromDb(row['card_scope'] as String),
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
  Future<List<ActiveSessionProgress>> fetchActiveSessions() async {
    final sessions = await _client
        .from('study_sessions')
        .select(
          'id, deck_id, study_mode, length_mode, card_scope, '
          'capped_length, started_at',
        )
        .eq('status', 'active')
        .order('started_at', ascending: false);
    if (sessions.isEmpty) return const [];

    final ids = [for (final s in sessions) s['id'] as String];
    // One join query for every active session's queue; `cards(mastery_level)`
    // rides the session_cards -> cards FK. RLS scopes it to the user's decks.
    final cardRows = await _client
        .from('session_cards')
        .select('session_id, is_parked, cards(mastery_level)')
        .inFilter('session_id', ids);

    final mastered = <String, int>{};
    final total = <String, int>{};
    for (final row in cardRows) {
      final sid = row['session_id'] as String;
      total[sid] = (total[sid] ?? 0) + 1;
      final card = row['cards'] as Map<String, dynamic>?;
      final level = card?['mastery_level'] as int? ?? 0;
      if ((row['is_parked'] as bool? ?? false) || level >= masteredLevel) {
        mastered[sid] = (mastered[sid] ?? 0) + 1;
      }
    }

    return [
      for (final s in sessions)
        ActiveSessionProgress(
          sessionId: s['id'] as String,
          deckId: s['deck_id'] as String,
          studyMode: studyModeFromDb(s['study_mode'] as String),
          lengthMode: sessionLengthModeFromDb(s['length_mode'] as String),
          cardScope: s['card_scope'] == null
              ? CardScope.due
              : cardScopeFromDb(s['card_scope'] as String),
          cappedLength: s['capped_length'] as int?,
          startedAt: DateTime.parse(s['started_at'] as String),
          masteredCards: mastered[s['id']] ?? 0,
          totalCards: total[s['id']] ?? 0,
        ),
    ];
  }

  @override
  Future<Map<String, int>> fetchSessionCountsByDeck() async {
    // supabase-dart has no GROUP BY, so pull the column and fold.
    final rows = await _client
        .from('study_sessions')
        .select('deck_id')
        .eq('status', 'completed');
    final counts = <String, int>{};
    for (final row in rows) {
      final deckId = row['deck_id'] as String;
      counts[deckId] = (counts[deckId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<CompletedSession>> fetchCompletedSessions({
    int limit = completedSessionsLimit,
  }) async {
    final rows = await _completedRows(limit, orderBy: 'started_at');
    return [
      for (final row in rows)
        CompletedSession(
          sessionId: row['id'] as String,
          deckId: row['deck_id'] as String,
          studyMode: studyModeFromDb(row['study_mode'] as String),
          lengthMode: sessionLengthModeFromDb(row['length_mode'] as String),
          cappedLength: row['capped_length'] as int?,
          cardScope: row['card_scope'] == null
              ? CardScope.due
              : cardScopeFromDb(row['card_scope'] as String),
          masteryDelta: row['mastery_delta'] as int?,
          startedAt: DateTime.parse(row['started_at'] as String),
          completedAt: row['completed_at'] == null
              ? null
              : DateTime.parse(row['completed_at'] as String),
          cardsReviewed: row['cards_reviewed'] as int?,
        ),
    ];
  }
}
