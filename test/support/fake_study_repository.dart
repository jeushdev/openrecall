import 'dart:async';

import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/queue_seed.dart';
import 'package:open_recall/features/study/domain/session_card.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_repository.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

/// In-memory [StudyRepository] for controller and widget tests.
///
/// Mirrors [FakeDeckRepository]'s style: a [calls] log, [throwOnNextCall], and
/// generated ids. [writeGate], when set, holds every mutating call open so a
/// test can assert ordering (e.g. mastery writes settle before
/// `completeSession`).
class FakeStudyRepository implements StudyRepository {
  FakeStudyRepository({
    List<StudySession>? sessions,
    List<SessionCard>? sessionCards,
  })  : _sessions = [...?sessions],
        _sessionCards = [...?sessionCards];

  final List<StudySession> _sessions;
  final List<SessionCard> _sessionCards;

  final List<String> calls = <String>[];
  Object? throwOnNextCall;

  /// When set, every mutating call awaits this before applying.
  Completer<void>? writeGate;

  final Map<String, int> _idSeq = {};
  String _nextId(String prefix) =>
      '$prefix-${_idSeq[prefix] = (_idSeq[prefix] ?? 0) + 1}';
  DateTime get _now => DateTime.utc(2026, 1, 1);

  List<StudySession> get sessions => List.unmodifiable(_sessions);

  StudySession? sessionById(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<SessionCard> sessionCardsFor(String sessionId) =>
      _sessionCards.where((sc) => sc.sessionId == sessionId).toList();

  SessionCard? sessionCardById(String id) {
    for (final sc in _sessionCards) {
      if (sc.id == id) return sc;
    }
    return null;
  }

  Future<void> _maybeThrow() async {
    await writeGate?.future;
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  @override
  Future<void> abandonActiveSessions(String deckId) async {
    calls.add('abandonActiveSessions($deckId)');
    await _maybeThrow();
    for (var i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      if (s.deckId == deckId && s.status == SessionStatus.active) {
        _sessions[i] = _withStatus(s, SessionStatus.abandoned);
      }
    }
  }

  @override
  Future<StudySession> createSession({
    required String deckId,
    required StudyMode studyMode,
    required SessionLengthMode lengthMode,
    int? cappedLength,
  }) async {
    calls.add('createSession(deck=$deckId, mode=${studyMode.name}, '
        'length=${lengthMode.db}, cap=$cappedLength)');
    await _maybeThrow();
    final session = StudySession(
      id: _nextId('session'),
      deckId: deckId,
      status: SessionStatus.active,
      studyMode: studyMode,
      lengthMode: lengthMode,
      cappedLength: cappedLength,
      masteryDelta: null,
      startedAt: _now,
      completedAt: null,
    );
    _sessions.add(session);
    return session;
  }

  @override
  Future<List<SessionCard>> createSessionCards(
    String sessionId,
    List<QueueSeed> seeds,
  ) async {
    calls.add('createSessionCards($sessionId, '
        'positions=${seeds.map((s) => s.position).toList()})');
    await _maybeThrow();
    final created = [
      for (final seed in seeds)
        SessionCard(
          id: _nextId('sc'),
          sessionId: sessionId,
          cardId: seed.cardId,
          position: seed.position,
          consecutiveFails: 0,
          isParked: false,
        ),
    ];
    _sessionCards.addAll(created);
    return created;
  }

  @override
  Future<void> updateSessionCard({
    required String sessionCardId,
    int? position,
    int? consecutiveFails,
    bool? isParked,
  }) async {
    calls.add('updateSessionCard(id=$sessionCardId, position=$position, '
        'consecutiveFails=$consecutiveFails, isParked=$isParked)');
    await _maybeThrow();
    final i = _sessionCards.indexWhere((sc) => sc.id == sessionCardId);
    if (i == -1) return;
    final sc = _sessionCards[i];
    _sessionCards[i] = SessionCard(
      id: sc.id,
      sessionId: sc.sessionId,
      cardId: sc.cardId,
      position: position ?? sc.position,
      consecutiveFails: consecutiveFails ?? sc.consecutiveFails,
      isParked: isParked ?? sc.isParked,
    );
  }

  @override
  Future<void> completeSession(String sessionId, {int? masteryDelta}) async {
    calls.add('completeSession($sessionId, masteryDelta=$masteryDelta)');
    await _maybeThrow();
    final i = _sessions.indexWhere((s) => s.id == sessionId);
    if (i == -1) return;
    final s = _sessions[i];
    _sessions[i] = StudySession(
      id: s.id,
      deckId: s.deckId,
      status: SessionStatus.completed,
      studyMode: s.studyMode,
      lengthMode: s.lengthMode,
      cappedLength: s.cappedLength,
      masteryDelta: masteryDelta ?? s.masteryDelta,
      startedAt: s.startedAt,
      completedAt: _now,
    );
  }

  StudySession _withStatus(StudySession s, SessionStatus status) => StudySession(
        id: s.id,
        deckId: s.deckId,
        status: status,
        studyMode: s.studyMode,
        lengthMode: s.lengthMode,
        cappedLength: s.cappedLength,
        masteryDelta: s.masteryDelta,
        startedAt: s.startedAt,
        completedAt: s.completedAt,
      );
}
