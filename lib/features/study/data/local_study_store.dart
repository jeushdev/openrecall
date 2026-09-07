import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/stale_account_scope.dart';

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
  LocalStudyStore(this._database, {this.isCurrent});

  final Database? _database;
  final bool Function()? isCurrent;
  Database? get _db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

  bool get isNoop => _db == null;

  // ---- writes -----------------------------------------------------------------

  Future<void> insertSession(
    StudySession session,
    String? userId, {
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.insert('offline_study_sessions', {
      'id': session.id,
      'deck_id': session.deckId,
      'user_id': userId,
      'status': session.status.name,
      'study_mode': session.studyMode.name,
      'length_mode': session.lengthMode.db,
      'capped_length': session.cappedLength,
      'card_scope': session.cardScope.db,
      'mastery_delta': session.masteryDelta,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'completed_at': session.completedAt?.toUtc().toIso8601String(),
      'is_synced': synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> hasSession(String sessionId) async {
    final db = _db;
    if (db == null) return false;
    final rows = await db.query(
      'offline_study_sessions',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<String?> sessionDeckId(String sessionId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query(
      'offline_study_sessions',
      columns: ['deck_id'],
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['deck_id'] as String;
  }

  Future<String?> sessionCardDeckId(String sessionCardId) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.rawQuery(
      '''
      SELECT s.deck_id
      FROM offline_session_cards sc
      JOIN offline_study_sessions s ON s.id = sc.session_id
      WHERE sc.id = ?
      LIMIT 1
      ''',
      [sessionCardId],
    );
    return rows.isEmpty ? null : rows.first['deck_id'] as String;
  }

  Future<void> insertSessionCards(
    List<SessionCard> rows, {
    required bool synced,
  }) async {
    final db = _db;
    if (db == null) return;
    final batch = db.batch();
    for (final sc in rows) {
      batch.insert('offline_session_cards', {
        'id': sc.id,
        'session_id': sc.sessionId,
        'card_id': sc.cardId,
        'position': sc.position,
        'consecutive_fails': sc.consecutiveFails,
        'is_parked': sc.isParked ? 1 : 0,
        'is_synced': synced ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final count = await db.update(
      'offline_session_cards',
      values,
      where: 'id = ?',
      whereArgs: [sessionCardId],
    );
    return count > 0;
  }

  Future<bool> abandonActiveSessions(
    String deckId, {
    required bool synced,
  }) async {
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
    int? masteryDelta,
    int? cardsReviewed, {
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
        'cards_reviewed': ?cardsReviewed,
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
    final rows = await db.query(
      'offline_study_sessions',
      where: 'is_synced = 0',
    );
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
          'card_scope': r['card_scope'],
          'mastery_delta': r['mastery_delta'],
          'cards_reviewed': r['cards_reviewed'],
          'started_at': r['started_at'],
          'completed_at': r['completed_at'],
        }),
    ];
  }

  Future<List<LocalSessionCardRow>> unsyncedSessionCards() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_session_cards',
      where: 'is_synced = 0',
    );
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

  /// Acknowledges only the exact session revisions handed to the remote
  /// upsert. A completion (or abandonment) committed while that request was in
  /// flight must remain dirty for the next pass.
  Future<void> markSessionsSynced(List<LocalSessionRow> sent) =>
      _markSynced('offline_study_sessions', sent.map((row) => row.values));

  /// The session-card counterpart of [markSessionsSynced]. Positions, fail
  /// counters and park decisions are the row's revision because the server
  /// table deliberately has no `updated_at` column.
  Future<void> markSessionCardsSynced(List<LocalSessionCardRow> sent) =>
      _markSynced(
        'offline_session_cards',
        sent.map(
          (row) => {
            ...row.values,
            'is_parked': row.values['is_parked'] == true ? 1 : 0,
          },
        ),
      );

  Future<void> _markSynced(
    String table,
    Iterable<Map<String, Object?>> sent,
  ) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final revision in sent) {
        final clauses = <String>['is_synced = 0'];
        final args = <Object?>[];
        for (final entry in revision.entries) {
          if (entry.value == null) {
            clauses.add('${entry.key} IS NULL');
          } else {
            clauses.add('${entry.key} = ?');
            args.add(entry.value);
          }
        }
        await txn.update(
          table,
          {'is_synced': 1},
          where: clauses.join(' AND '),
          whereArgs: args,
        );
      }
    });
  }
}
