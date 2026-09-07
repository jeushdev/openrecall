import 'package:sqflite/sqflite.dart';

import '../../../core/local_db/stale_account_scope.dart';

import '../../decks/domain/card.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';

import '../domain/active_session.dart';
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
  LocalStatsStore(this._database, {this.isCurrent});

  final Database? _database;
  final bool Function()? isCurrent;
  Database? get _db {
    if (isCurrent?.call() == false) throw const StaleAccountScope();
    return _database;
  }

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
      columns: [
        'deck_id',
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
          deckId: r['deck_id'] as String,
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
      final rows = await db.rawQuery(
        'SELECT sc.is_parked AS is_parked, c.mastery_level AS mastery_level '
        'FROM offline_session_cards sc '
        'LEFT JOIN offline_cards c ON c.id = sc.card_id '
        'WHERE sc.session_id = ?',
        [s['id']],
      );
      var mastered = 0;
      for (final r in rows) {
        final parked = (r['is_parked'] as int? ?? 0) == 1;
        final level = r['mastery_level'] as int? ?? 0;
        if (parked || level >= masteredLevel) mastered++;
      }
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
          totalCards: rows.length,
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
