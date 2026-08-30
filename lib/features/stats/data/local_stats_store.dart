import 'package:sqflite/sqflite.dart';

import '../domain/troublemaker_card.dart';

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

  /// Downloaded cards with the highest `fail_count`, most-failed first, capped at
  /// [limit]. No `fail_count` threshold — matches the remote query.
  Future<List<TroublemakerCard>> troublemakers(int limit) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_cards',
      columns: ['id', 'deck_id', 'front', 'back', 'fail_count'],
      orderBy: 'fail_count DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        TroublemakerCard(
          id: r['id'] as String,
          deckId: r['deck_id'] as String,
          front: r['front'] as String,
          back: r['back'] as String,
          failCount: r['fail_count'] as int,
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

  /// `started_at` of every locally-recorded `completed` session, most-recent
  /// first — the streak input (ui-spec-v1 §6.4). Partial by nature: only
  /// sessions that ran on this device are mirrored.
  Future<List<DateTime>> completedSessionStarts() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_study_sessions',
      columns: ['started_at'],
      where: 'status = ?',
      whereArgs: ['completed'],
      orderBy: 'started_at DESC',
    );
    return [
      for (final r in rows) DateTime.parse(r['started_at'] as String),
    ];
  }
}
