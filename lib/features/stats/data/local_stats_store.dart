import 'package:sqflite/sqflite.dart';

import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';

/// Read-only DAO for the cross-deck stat aggregations (engine-v2-spec §6),
/// computed straight from the local mirror when the app is offline.
///
/// It reads tables the deck / study stores own (`offline_cards`,
/// `offline_study_sessions`) but never writes them, so there is no overlap of
/// responsibility. As with the other local stores, a `null` database makes every
/// read return empty.
///
/// Offline results are **partial** by nature: `offline_cards` only holds
/// downloaded decks, and `offline_study_sessions` only holds sessions that ran
/// on this device. The online path is the source of truth.
class LocalStatsStore {
  LocalStatsStore(this._db);

  final Database? _db;

  bool get isNoop => _db == null;

  /// The most recently `completed` sessions recorded on this device, newest
  /// first, capped at [limit] — the offline fallback for the Mastery tab's
  /// activity feed (milestone C). Partial by nature: only sessions that ran on
  /// this device are mirrored.
  Future<List<CompletedSessionActivity>> recentCompletedSessions(
    int limit,
  ) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_study_sessions',
      columns: ['deck_id', 'completed_at', 'mastery_delta'],
      where: 'status = ? AND completed_at IS NOT NULL',
      whereArgs: ['completed'],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        CompletedSessionActivity(
          deckId: r['deck_id'] as String,
          completedAt: DateTime.parse(r['completed_at'] as String),
          masteryDelta: r['mastery_delta'] as int?,
        ),
    ];
  }

  /// "Times fully cleared" per deck from locally-recorded sessions
  /// (engine-v2-spec §4.3): completed sessions with `card_scope = 'all'`, grouped
  /// by deck. Decks with no such session are absent.
  Future<Map<String, int>> runThroughsByDeck() async {
    final db = _db;
    if (db == null) return const {};
    final rows = await db.rawQuery(
      'SELECT deck_id, COUNT(*) AS c FROM offline_study_sessions '
      'WHERE status = ? AND card_scope = ? GROUP BY deck_id',
      ['completed', 'all'],
    );
    return {
      for (final r in rows) r['deck_id'] as String: r['c'] as int,
    };
  }

  /// Every locally-recorded `completed` session, most-recent first, capped at
  /// [limit] — the input for the Profile tab's streaks and study-volume metrics
  /// (milestone D). Partial by nature: only sessions that ran on this device are
  /// mirrored.
  Future<List<CompletedSession>> completedSessions(int limit) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_study_sessions',
      columns: ['started_at', 'completed_at', 'cards_reviewed'],
      where: 'status = ?',
      whereArgs: ['completed'],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        CompletedSession(
          startedAt: DateTime.parse(r['started_at'] as String),
          completedAt: r['completed_at'] == null
              ? null
              : DateTime.parse(r['completed_at'] as String),
          cardsReviewed: r['cards_reviewed'] as int?,
        ),
    ];
  }
}
