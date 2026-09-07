import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/application_cache.dart';
import '../../../core/local_db/stale_account_scope.dart';

import '../../decks/domain/card.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';

import '../domain/active_session.dart';
import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';

const recentSessionsCacheKey = 'sessions.recent.20';
const completedSessionsCacheKey = 'sessions.completed.1000';
const activeSessionsCacheKey = 'sessions.active';

class SessionCacheState {
  const SessionCacheState({
    required this.available,
    this.fetchedAt,
    this.coverage,
  });

  final bool available;
  final DateTime? fetchedAt;
  final CacheCoverage? coverage;
  bool get hasCachedData => fetchedAt != null;
  bool get isComplete => coverage == CacheCoverage.complete;
}

/// DAO for durable session projections and cross-deck stat aggregations,
/// computed straight from the existing local session mirror.
///
/// Remote session rows are merged into `offline_study_sessions` without
/// replacing pending local rows. As with the other local stores, a `null`
/// database makes every operation a no-op.
class LocalStatsStore {
  LocalStatsStore(this._database, {this.isCurrent});

  final Database? _database;
  final bool Function()? isCurrent;
  Database? get _db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

  bool get isNoop => _db == null;

  Future<SessionCacheState> cacheState(String key) async {
    final db = _db;
    if (db == null) return const SessionCacheState(available: false);
    final rows = await db.query(
      'application_cache',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return const SessionCacheState(available: true);
    final row = rows.single;
    return SessionCacheState(
      available: true,
      fetchedAt: DateTime.parse(row['fetched_at'] as String),
      coverage: CacheCoverage.values.byName(row['coverage'] as String),
    );
  }

  Future<void> _markFetched(
    Transaction txn,
    String key,
    CacheCoverage coverage,
  ) => txn.insert('application_cache', {
    'key': key,
    'fetched_at': DateTime.now().toUtc().toIso8601String(),
    'coverage': coverage.name,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveRecentCompletedSessions(
    List<CompletedSessionActivity> sessions, {
    required CacheCoverage coverage,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final session in sessions) {
        if (session.sessionId == null || session.startedAt == null) continue;
        await txn.rawInsert(
          '''
          INSERT INTO offline_study_sessions
            (id, deck_id, status, study_mode, length_mode, capped_length,
             card_scope, mastery_delta, cards_reviewed, started_at,
             completed_at, is_synced)
          VALUES (?, ?, 'completed', ?, ?, ?, ?, ?, ?, ?, ?, 1)
          ON CONFLICT(id) DO UPDATE SET
            deck_id = excluded.deck_id,
            status = excluded.status,
            study_mode = excluded.study_mode,
            length_mode = excluded.length_mode,
            capped_length = excluded.capped_length,
            card_scope = excluded.card_scope,
            mastery_delta = excluded.mastery_delta,
            cards_reviewed = excluded.cards_reviewed,
            started_at = excluded.started_at,
            completed_at = excluded.completed_at
          WHERE offline_study_sessions.is_synced = 1
        ''',
          [
            session.sessionId,
            session.deckId,
            session.studyMode.name,
            (session.lengthMode ?? SessionLengthMode.untilMastered).db,
            session.cappedLength,
            (session.cardScope ?? CardScope.due).db,
            session.masteryDelta,
            session.cardsReviewed,
            session.startedAt!.toUtc().toIso8601String(),
            session.completedAt.toUtc().toIso8601String(),
          ],
        );
      }
      await _markFetched(txn, recentSessionsCacheKey, coverage);
    });
  }

  Future<void> saveCompletedSessions(
    List<CompletedSession> sessions, {
    required CacheCoverage coverage,
  }) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      for (final session in sessions) {
        if (session.sessionId == null ||
            session.deckId == null ||
            session.studyMode == null) {
          continue;
        }
        await txn.rawInsert(
          '''
          INSERT INTO offline_study_sessions
            (id, deck_id, status, study_mode, length_mode, capped_length,
             card_scope, mastery_delta, cards_reviewed, started_at,
             completed_at, is_synced)
          VALUES (?, ?, 'completed', ?, ?, ?, ?, ?, ?, ?, ?, 1)
          ON CONFLICT(id) DO UPDATE SET
            deck_id = excluded.deck_id,
            status = excluded.status,
            study_mode = excluded.study_mode,
            length_mode = excluded.length_mode,
            capped_length = excluded.capped_length,
            card_scope = excluded.card_scope,
            mastery_delta = excluded.mastery_delta,
            cards_reviewed = excluded.cards_reviewed,
            started_at = excluded.started_at,
            completed_at = excluded.completed_at
          WHERE offline_study_sessions.is_synced = 1
        ''',
          [
            session.sessionId,
            session.deckId,
            session.studyMode!.name,
            (session.lengthMode ?? SessionLengthMode.untilMastered).db,
            session.cappedLength,
            (session.cardScope ?? CardScope.due).db,
            session.masteryDelta,
            session.cardsReviewed,
            session.startedAt.toUtc().toIso8601String(),
            session.completedAt?.toUtc().toIso8601String(),
          ],
        );
      }
      await _markFetched(txn, completedSessionsCacheKey, coverage);
    });
  }

  Future<void> saveActiveSessions(List<ActiveSessionProgress> sessions) async {
    final db = _db;
    if (db == null) return;
    await db.transaction((txn) async {
      await txn.delete('cached_active_progress');
      final remoteIds = sessions.map((session) => session.sessionId).toList();
      await txn.delete(
        'offline_study_sessions',
        where: remoteIds.isEmpty
            ? 'status = ? AND is_synced = 1'
            : 'status = ? AND is_synced = 1 AND '
                  'id NOT IN (${List.filled(remoteIds.length, '?').join(',')})',
        whereArgs: ['active', ...remoteIds],
      );
      for (final session in sessions) {
        final existing = await txn.query(
          'offline_study_sessions',
          columns: ['is_synced'],
          where: 'id = ?',
          whereArgs: [session.sessionId],
          limit: 1,
        );
        final pendingLocal =
            existing.isNotEmpty && existing.single['is_synced'] == 0;
        await txn.rawInsert(
          '''
          INSERT INTO offline_study_sessions
            (id, deck_id, status, study_mode, length_mode, capped_length,
             card_scope, started_at, is_synced)
          VALUES (?, ?, 'active', ?, ?, ?, ?, ?, 1)
          ON CONFLICT(id) DO UPDATE SET
            deck_id = excluded.deck_id,
            status = excluded.status,
            study_mode = excluded.study_mode,
            length_mode = excluded.length_mode,
            capped_length = excluded.capped_length,
            card_scope = excluded.card_scope,
            started_at = excluded.started_at
          WHERE offline_study_sessions.is_synced = 1
        ''',
          [
            session.sessionId,
            session.deckId,
            session.studyMode.name,
            session.lengthMode.db,
            session.cappedLength,
            session.cardScope.db,
            session.startedAt.toUtc().toIso8601String(),
          ],
        );
        if (!pendingLocal) {
          await txn.insert('cached_active_progress', {
            'session_id': session.sessionId,
            'mastered': session.masteredCards,
            'total': session.totalCards,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await _markFetched(txn, activeSessionsCacheKey, CacheCoverage.complete);
    });
  }

  /// The most recently persisted `completed` sessions, newest first, capped at
  /// [limit], including both account history and pending local completions.
  Future<List<CompletedSessionActivity>> recentCompletedSessions(
    int limit,
  ) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_study_sessions',
      columns: [
        'id',
        'deck_id',
        'started_at',
        'completed_at',
        'mastery_delta',
        'study_mode',
        'cards_reviewed',
      ],
      where: 'status = ? AND completed_at IS NOT NULL',
      whereArgs: ['completed'],
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        CompletedSessionActivity(
          sessionId: r['id'] as String,
          deckId: r['deck_id'] as String,
          startedAt: DateTime.parse(r['started_at'] as String),
          completedAt: DateTime.parse(r['completed_at'] as String),
          masteryDelta: r['mastery_delta'] as int?,
          studyMode: studyModeFromDb(r['study_mode'] as String),
          cardsReviewed: r['cards_reviewed'] as int?,
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
    return {for (final r in rows) r['deck_id'] as String: r['c'] as int};
  }

  /// Every locally-mirrored still-`active` session with its mastered/total
  /// figures (ui-spec-v4 §3), newest first. Progress is recomputed from
  /// `offline_session_cards` joined to `offline_cards.mastery_level` — a
  /// session-card row is never rewritten when its card is mastered, so the
  /// card's live level is the signal. Partial by nature: only downloaded decks
  /// and on-device sessions are mirrored.
  Future<List<ActiveSessionProgress>> activeSessions() async {
    final db = _db;
    if (db == null) return const [];
    final sessions = await db.query(
      'offline_study_sessions',
      columns: [
        'id',
        'deck_id',
        'study_mode',
        'length_mode',
        'card_scope',
        'capped_length',
        'started_at',
      ],
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'started_at DESC',
    );
    if (sessions.isEmpty) return const [];

    final result = <ActiveSessionProgress>[];
    for (final s in sessions) {
      final cachedRows = await db.query(
        'cached_active_progress',
        where: 'session_id = ?',
        whereArgs: [s['id']],
        limit: 1,
      );
      final rows = await db.rawQuery(
        'SELECT sc.is_parked AS is_parked, c.mastery_level AS mastery_level '
        'FROM offline_session_cards sc '
        'LEFT JOIN offline_cards c ON c.id = sc.card_id '
        'WHERE sc.session_id = ?',
        [s['id']],
      );
      var mastered = cachedRows.isEmpty
          ? 0
          : cachedRows.single['mastered'] as int;
      if (cachedRows.isEmpty) {
        for (final r in rows) {
          final parked = (r['is_parked'] as int? ?? 0) == 1;
          final level = r['mastery_level'] as int? ?? 0;
          if (parked || level >= masteredLevel) mastered++;
        }
      }
      final total = cachedRows.isEmpty
          ? rows.length
          : cachedRows.single['total'] as int;
      result.add(
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
          masteredCards: mastered,
          totalCards: total,
        ),
      );
    }
    return result;
  }

  /// Completed-session count per deck from on-device sessions, all card scopes
  /// (ui-spec-v4 §3). Decks with no completed session are absent.
  Future<Map<String, int>> sessionCountsByDeck() async {
    final db = _db;
    if (db == null) return const {};
    final rows = await db.rawQuery(
      'SELECT deck_id, COUNT(*) AS c FROM offline_study_sessions '
      'WHERE status = ? GROUP BY deck_id',
      ['completed'],
    );
    return {for (final r in rows) r['deck_id'] as String: r['c'] as int};
  }

  /// Every persisted `completed` session, most-recent first, capped at [limit]
  /// — the input for History and profile study-volume metrics.
  Future<List<CompletedSession>> completedSessions(int limit) async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query(
      'offline_study_sessions',
      columns: [
        'id',
        'deck_id',
        'study_mode',
        'length_mode',
        'capped_length',
        'card_scope',
        'mastery_delta',
        'started_at',
        'completed_at',
        'cards_reviewed',
      ],
      where: 'status = ?',
      whereArgs: ['completed'],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        CompletedSession(
          sessionId: r['id'] as String,
          deckId: r['deck_id'] as String,
          studyMode: studyModeFromDb(r['study_mode'] as String),
          lengthMode: sessionLengthModeFromDb(r['length_mode'] as String),
          cappedLength: r['capped_length'] as int?,
          cardScope: cardScopeFromDb(r['card_scope'] as String? ?? 'due'),
          masteryDelta: r['mastery_delta'] as int?,
          startedAt: DateTime.parse(r['started_at'] as String),
          completedAt: r['completed_at'] == null
              ? null
              : DateTime.parse(r['completed_at'] as String),
          cardsReviewed: r['cards_reviewed'] as int?,
        ),
    ];
  }
}
