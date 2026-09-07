import '../../../core/ids.dart';
import '../../decks/data/local_deck_store.dart';
import '../../decks/domain/study_mode.dart';
import '../domain/queue_seed.dart';
import '../domain/session_card.dart';
import '../domain/session_length.dart';
import '../domain/session_status.dart';
import '../domain/study_repository.dart';
import '../domain/study_session.dart';
import 'local_study_store.dart';

/// Wraps the Supabase-backed repository with the local session mirror (spec
/// §10), so a downloaded deck's session can be created, advanced and completed
/// with no connectivity.
///
/// Complete local deck packages use SQLite as the study write authority: every
/// session and queue mutation commits locally and is marked unsynced before a
/// background [SyncService] pass may run. This keeps study interactions clear
/// of network latency while retaining permanent client-generated UUIDs and the
/// existing `cards → study_sessions → session_cards` dependency order.
///
/// Without a complete package (including when SQLite is unavailable), methods
/// retain the online-only Supabase behavior.
class CacheFirstStudyRepository implements StudyRepository {
  CacheFirstStudyRepository(
    this._remote,
    this._local,
    this._deckLocal,
    this._currentUserId,
  );

  final StudyRepository _remote;
  final LocalStudyStore _local;
  final LocalDeckStore _deckLocal;
  final String? Function() _currentUserId;

  @override
  Future<void> abandonActiveSessions(String deckId) async {
    if (await _deckLocal.isCardSetComplete(deckId)) {
      await _local.abandonActiveSessions(deckId, synced: false);
      return;
    }
    await _remote.abandonActiveSessions(deckId);
  }

  @override
  Future<StudySession> createSession({
    required String deckId,
    required StudyMode studyMode,
    required SessionLengthMode lengthMode,
    int? cappedLength,
    CardScope cardScope = CardScope.due,
  }) async {
    if (!await _deckLocal.isCardSetComplete(deckId)) {
      return _remote.createSession(
        deckId: deckId,
        studyMode: studyMode,
        lengthMode: lengthMode,
        cappedLength: cappedLength,
        cardScope: cardScope,
      );
    }

    final session = StudySession(
      id: newUuid(),
      deckId: deckId,
      status: SessionStatus.active,
      studyMode: studyMode,
      lengthMode: lengthMode,
      cappedLength: cappedLength,
      cardScope: cardScope,
      masteryDelta: null,
      startedAt: DateTime.now().toUtc(),
      completedAt: null,
    );
    await _local.insertSession(session, _currentUserId(), synced: false);
    return session;
  }

  @override
  Future<List<SessionCard>> createSessionCards(
    String sessionId,
    List<QueueSeed> seeds,
  ) async {
    final deckId = await _local.sessionDeckId(sessionId);
    if (deckId != null && await _deckLocal.isCardSetComplete(deckId)) {
      final rows = [
        for (final seed in seeds)
          SessionCard(
            id: newUuid(),
            sessionId: sessionId,
            cardId: seed.cardId,
            position: seed.position,
            consecutiveFails: 0,
            isParked: false,
          ),
      ];
      await _local.insertSessionCards(rows, synced: false);
      return rows;
    }
    return _remote.createSessionCards(sessionId, seeds);
  }

  @override
  Future<void> updateSessionCard({
    required String sessionCardId,
    int? position,
    int? consecutiveFails,
    bool? isParked,
  }) async {
    final deckId = await _local.sessionCardDeckId(sessionCardId);
    if (deckId != null && await _deckLocal.isCardSetComplete(deckId)) {
      final applied = await _local.updateSessionCard(
        sessionCardId,
        position: position,
        consecutiveFails: consecutiveFails,
        isParked: isParked,
        synced: false,
      );
      if (applied) return;
    }
    await _remote.updateSessionCard(
      sessionCardId: sessionCardId,
      position: position,
      consecutiveFails: consecutiveFails,
      isParked: isParked,
    );
  }

  @override
  Future<void> completeSession(
    String sessionId, {
    int? masteryDelta,
    int? cardsReviewed,
  }) async {
    final deckId = await _local.sessionDeckId(sessionId);
    if (deckId != null && await _deckLocal.isCardSetComplete(deckId)) {
      final applied = await _local.completeSession(
        sessionId,
        masteryDelta,
        cardsReviewed,
        synced: false,
      );
      if (applied) return;
    }
    await _remote.completeSession(
      sessionId,
      masteryDelta: masteryDelta,
      cardsReviewed: cardsReviewed,
    );
  }
}
