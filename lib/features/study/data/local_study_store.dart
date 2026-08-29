import 'package:sqflite/sqflite.dart';

import '../domain/session_card.dart';
import '../domain/session_length.dart';
import '../domain/study_session.dart';

/// A local `study_sessions` row awaiting sync, in the plain shape the upsert to
/// Supabase needs.
class LocalSessionRow {
  LocalSessionRow(this.values);
  final Map<String, Object?> values;
  String get id => values['id'] as String;
}

/// A local `session_cards` row awaiting sync.
class LocalSessionCardRow {
  LocalSessionCardRow(this.values);
  final Map<String, Object?> values;
  String get id => values['id'] as String;
}

/// DAO for the `offline_study_sessions` / `offline_session_cards` tables
/// (spec §10) — the mirror that lets a downloaded deck's session be started and
/// finished with no connectivity.
///
/// As with [LocalDeckStore], a `null` database makes every method a no-op so a
/// cache-first repository degrades cleanly to online-only.
class LocalStudyStore {
  LocalStudyStore(this._db);

  final Database? _db;

  bool get isNoop => _db == null;

  // ---- writes -----------------------------------------------------------------

  Future<void> insertSession(
    StudySession session,
    String? userId, {
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'offline_study_sessions',
      {
        'id': session.id,
        'deck_id': session.deckId,
        'user_id': userId,
        'status': session.status.name,
        'study_mode': session.studyMode.name,
        'length_mode': session.lengthMode.db,
        'capped_length': session.cappedLength,
        'mastery_delta': session.masteryDelta,
        'started_at': session.startedAt.toUtc().toIso8601String(),
        'completed_at': session.completedAt?.toUtc().toIso8601String(),
        'is_synced': synced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasSession(String sessionId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query('offline_study_sessions',
        columns: ['id'], where: 'id = ?', whereArgs: [sessionId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> insertSessionCards(
    List<SessionCard> rows, {
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return;
    final batch = db.batch();
    for (final sc in rows) {
      batch.insert(
        'offline_session_cards',
        {
          'id': sc.id,
          'session_id': sc.sessionId,
          'card_id': sc.cardId,
          'position': sc.position,
          'consecutive_fails': sc.consecutiveFails,
          'is_parked': sc.isParked ? 1 : 0,
          'is_synced': synced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Applies a `session_cards` field write locally. Returns `false` if no such
  /// local row exists (a non-downloaded deck), so the caller can decide whether
  /// the missing mirror is an error.
  Future<bool> updateSessionCard(
    String sessionCardId, {
    int? position,
    int? consecutiveFails,
    bool? isParked,
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return false;
    final values = <String, Object?>{
      'position': ?position,
      'consecutive_fails': ?consecutiveFails,
      if (isParked != null) 'is_parked': isParked ? 1 : 0,
      'is_synced': synced ? 1 : 0,
    };
    final count = await db.update('offline_session_cards', values,
        where: 'id = ?', whereArgs: [sessionCardId]);
    return count > 0;
  }

  Future<bool> abandonActiveSessions(String deckId, {required bool synced}) async {
    final db = _db;
    if (db == null) return false;
    final count = await db.update(
      'offline_study_sessions',
      {'status': 'abandoned', 'is_synced': synced ? 1 : 0},
      where: 'deck_id = ? AND status = ?',
      whereArgs: [deckId, 'active'],
    );
    return count > 0;
  }

  Future<bool> completeSession(
    String sessionId,
    int? masteryDelta, {
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return false;
    final count = await db.update(
      'offline_study_sessions',
      {
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'mastery_delta': ?masteryDelta,
        'is_synced': synced ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return count > 0;
  }

  // ---- sync support ---------------------------------------------------------

  Future<List<LocalSessionRow>> unsyncedSessions() async {
    final db = _db;
    if (db == null) return const [];
    final rows =
        await db.query('offline_study_sessions', where: 'is_synced = 0');
    return [
      for (final r in rows)
        LocalSessionRow({
          'id': r['id'],
          'user_id': r['user_id'],
          'deck_id': r['deck_id'],
          'status': r['status'],
          'study_mode': r['study_mode'],
          'length_mode': r['length_mode'],
          'capped_length': r['capped_length'],
          'mastery_delta': r['mastery_delta'],
          'started_at': r['started_at'],
          'completed_at': r['completed_at'],
        }),
    ];
  }

  Future<List<LocalSessionCardRow>> unsyncedSessionCards() async {
    final db = _db;
    if (db == null) return const [];
    final rows =
        await db.query('offline_session_cards', where: 'is_synced = 0');
    return [
      for (final r in rows)
        LocalSessionCardRow({
          'id': r['id'],
          'session_id': r['session_id'],
          'card_id': r['card_id'],
          'position': r['position'],
          'consecutive_fails': r['consecutive_fails'],
          'is_parked': (r['is_parked'] as int) == 1,
        }),
    ];
  }

  Future<void> markSessionsSynced(List<String> ids) => _markSynced(
      'offline_study_sessions', ids);

  Future<void> markSessionCardsSynced(List<String> ids) =>
      _markSynced('offline_session_cards', ids);

  Future<void> _markSynced(String table, List<String> ids) async {
    final db = _db;
    if (db == null || ids.isEmpty) return;
    await db.update(
      table,
      {'is_synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }
}
