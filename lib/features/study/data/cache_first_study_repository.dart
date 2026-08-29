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
import 'supabase_study_repository.dart';

/// Wraps [SupabaseStudyRepository] with the local session mirror (spec §10), so
/// a downloaded deck's session can be created, advanced and completed with no
/// connectivity.
///
/// Every method tries Supabase first and mirrors the result locally for
/// downloaded decks. If the Supabase call throws and the deck is downloaded, it
/// writes to the mirror instead and marks the row unsynced; the reconnect pass
/// ([SyncService]) upserts those rows in `cards → study_sessions →
/// session_cards` order. A fully-offline session gets a client-generated UUID
/// from creation, so nothing has to be renumbered once it syncs.
class CacheFirstStudyRepository implements StudyRepository {
  CacheFirstStudyRepository(
    this._remote,
    this._local,
    this._deckLocal,
    this._currentUserId,
  );

  final SupabaseStudyRepository _remote;
  final LocalStudyStore _local;
  final LocalDeckStore _deckLocal;
  final String? Function() _currentUserId;

  @override
  Future<void> abandonActiveSessions(String deckId) async {
    try {
      await _remote.abandonActiveSessions(deckId);
      await _local.abandonActiveSessions(deckId, synced: true);
    } catch (_) {
      if (!await _deckLocal.isDownloaded(deckId)) rethrow;
      await _local.abandonActiveSessions(deckId, synced: false);
    }
  }

  @override
  Future<StudySession> createSession({
    required String deckId,
    required StudyMode studyMode,
    required SessionLengthMode lengthMode,
    int? cappedLength,
  }) async {
    try {
      final session = await _remote.createSession(
        deckId: deckId,
        studyMode: studyMode,
        lengthMode: lengthMode,
        cappedLength: cappedLength,
      );
      if (await _deckLocal.isDownloaded(deckId)) {
        await _local.insertSession(session, _currentUserId(), synced: true);
      }
      return session;
    } catch (_) {
      if (!await _deckLocal.isDownloaded(deckId)) rethrow;
      final session = StudySession(
        id: newUuid(),
        deckId: deckId,
        status: SessionStatus.active,
        studyMode: studyMode,
        lengthMode: lengthMode,
        cappedLength: cappedLength,
        masteryDelta: null,
        startedAt: DateTime.now().toUtc(),
        completedAt: null,
      );
      await _local.insertSession(session, _currentUserId(), synced: false);
      return session;
    }
  }

  @override
  Future<List<SessionCard>> createSessionCards(
    String sessionId,
    List<QueueSeed> seeds,
  ) async {
    try {
      final rows = await _remote.createSessionCards(sessionId, seeds);
      if (await _local.hasSession(sessionId)) {
        await _local.insertSessionCards(rows, synced: true);
      }
      return rows;
    } catch (_) {
      if (!await _local.hasSession(sessionId)) rethrow;
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
  }

  @override
  Future<void> updateSessionCard({
    required String sessionCardId,
    int? position,
    int? consecutiveFails,
    bool? isParked,
  }) async {
    try {
      await _remote.updateSessionCard(
        sessionCardId: sessionCardId,
        position: position,
        consecutiveFails: consecutiveFails,
        isParked: isParked,
      );
      await _local.updateSessionCard(
        sessionCardId,
        position: position,
        consecutiveFails: consecutiveFails,
        isParked: isParked,
        synced: true,
      );
    } catch (_) {
      final applied = await _local.updateSessionCard(
        sessionCardId,
        position: position,
        consecutiveFails: consecutiveFails,
        isParked: isParked,
        synced: false,
      );
      if (!applied) rethrow;
    }
  }

  @override
  Future<void> completeSession(String sessionId, {int? masteryDelta}) async {
    try {
      await _remote.completeSession(sessionId, masteryDelta: masteryDelta);
      await _local.completeSession(sessionId, masteryDelta, synced: true);
    } catch (_) {
      final applied =
          await _local.completeSession(sessionId, masteryDelta, synced: false);
      if (!applied) rethrow;
    }
  }
}
