import 'package:flutter/foundation.dart';

import '../../decks/domain/card.dart';
import 'flip_rating.dart';
import 'requeue.dart';
import 'session_outcome.dart';
import 'study_attempt.dart';
import 'study_queue_item.dart';
import 'study_session.dart';

/// Where the study screen is in the loop.
enum SessionPhase {
  /// Showing a card, waiting for a rating.
  studying,

  /// A card just hit its third consecutive fail — waiting on the "park this
  /// card?" answer.
  parkPrompt,

  /// Every queued card is Mastered or parked (spec §5). Terminal.
  completed,
}

/// Whether the current card is a new attempt or has returned after a
/// below-Mastered result in this live session.
enum CardAppearance { firstAttempt, returning }

/// The side effects a rating produces that the controller must persist. Pure
/// data — [StudySessionState.applyRating] returns one alongside the next state.
@immutable
class RatingEffects {
  const RatingEffects({
    required this.cardId,
    required this.sessionCardId,
    required this.newMasteryLevel,
    required this.isFail,
    required this.newPosition,
    required this.newConsecutiveFails,
    required this.promptPark,
  });

  final String cardId;
  final String sessionCardId;

  /// The `cards.mastery_level` this rating writes (0–4).
  final int newMasteryLevel;

  /// Whether this was a fail (anything short of Mastered) — drives the lifetime
  /// `cards.fail_count` increment.
  final bool isFail;

  /// The card's new `session_cards.position` after a requeue, or `null` if it
  /// left the queue (Mastered).
  final int? newPosition;

  /// The card's new `session_cards.consecutive_fails`.
  final int newConsecutiveFails;

  /// Whether the caller should show the "park this card?" prompt.
  final bool promptPark;
}

/// The in-memory session engine (spec §5/§6). Immutable; every transition
/// returns a fresh state. The controller owns persistence — this type only
/// decides what the queue and phase become.
@immutable
class StudySessionState {
  const StudySessionState({
    required this.session,
    required this.deckId,
    required this.deckName,
    required this.queue,
    required this.masteredCardIds,
    required this.parkedCardIds,
    required this.totalCards,
    required this.phase,
    required this.pendingParkSessionCardId,
    required this.attemptMetadata,
    this.outcome,
  });

  /// Builds the starting state from the seeded queue items. Sorts by position,
  /// freezes [totalCards], and completes immediately if [items] is empty.
  factory StudySessionState.initial({
    required StudySession session,
    required String deckId,
    required String? deckName,
    required List<StudyQueueItem> items,
  }) {
    final queue = [...items]..sort((a, b) => a.position.compareTo(b.position));
    return StudySessionState(
      session: session,
      deckId: deckId,
      deckName: deckName,
      queue: List.unmodifiable(queue),
      masteredCardIds: const {},
      parkedCardIds: const {},
      totalCards: items.length,
      phase: queue.isEmpty ? SessionPhase.completed : SessionPhase.studying,
      pendingParkSessionCardId: null,
      attemptMetadata: const {},
    );
  }

  final StudySession session;
  final String deckId;
  final String? deckName;

  /// The remaining cards, always sorted ascending by position. Mastered and
  /// parked cards are removed.
  final List<StudyQueueItem> queue;
  final Set<String> masteredCardIds;
  final Set<String> parkedCardIds;

  /// The number of distinct cards this session covers, frozen at seed time.
  final int totalCards;
  final SessionPhase phase;

  /// The `session_cards.id` awaiting a park answer, set iff [phase] is
  /// [SessionPhase.parkPrompt].
  final String? pendingParkSessionCardId;

  /// Attempt activity retained for the lifetime of this in-memory session,
  /// including after cards leave the queue.
  final Map<StudyAttemptId, StudyAttemptMetadata> attemptMetadata;

  /// The Session Summary figures (spec §7), set by the controller once [phase]
  /// reaches [SessionPhase.completed]. `null` until then.
  final SessionOutcome? outcome;

  StudyQueueItem? get current => queue.isEmpty ? null : queue.first;

  StudyAttemptId? get currentAttemptId {
    final item = current;
    if (item == null) return null;
    return StudyAttemptId(
      sessionId: session.id,
      sessionCardId: item.sessionCardId,
      queuePosition: item.position,
    );
  }

  bool hintUsedFor(StudyAttemptId attemptId) =>
      attemptMetadata[attemptId]?.hintUsed ?? false;

  /// Records activity only for the card attempt that is actively studying.
  /// Logical OR makes assistance impossible to erase with a later write.
  StudySessionState recordAttemptMetadata(
    StudyAttemptId attemptId, {
    required bool hintUsed,
  }) {
    if (phase != SessionPhase.studying || currentAttemptId != attemptId) {
      return this;
    }
    final previous = attemptMetadata[attemptId];
    final next = previous == null
        ? StudyAttemptMetadata(hintUsed: hintUsed)
        : previous.merge(hintUsed: hintUsed);
    if (previous == next) return this;
    return _copy(attemptMetadata: {...attemptMetadata, attemptId: next});
  }

  /// The current card's retry appearance, or `null` when there is no card.
  CardAppearance? get currentCardAppearance {
    final item = current;
    if (item == null) return null;
    return item.requeueCount == 0
        ? CardAppearance.firstAttempt
        : CardAppearance.returning;
  }

  int get resolvedCount => masteredCardIds.length + parkedCardIds.length;

  bool get isComplete => phase == SessionPhase.completed;

  /// Applies a Flip rating to the current card. Caller must ensure
  /// [phase] is [SessionPhase.studying].
  ({StudySessionState state, RatingEffects effects}) applyRating(
    FlipRating rating,
  ) => applyResult(masteryLevel: rating.level);

  /// Applies a mode-neutral result to the current card: the mode has already
  /// translated its raw outcome into a `mastery_level` (spec §6). Reaching
  /// [masteredLevel] retires the card; anything less requeues it, bumps the
  /// consecutive-fail counter, and prompts a park on the third. Caller must
  /// ensure [phase] is [SessionPhase.studying].
  ({StudySessionState state, RatingEffects effects}) applyResult({
    required int masteryLevel,
  }) {
    assert(phase == SessionPhase.studying);
    final item = queue.first;

    if (masteryLevel >= masteredLevel) {
      final next = _copy(
        queue: queue.sublist(1),
        masteredCardIds: {...masteredCardIds, item.cardId},
        phase: queue.length == 1
            ? SessionPhase.completed
            : SessionPhase.studying,
      );
      return (
        state: next,
        effects: RatingEffects(
          cardId: item.cardId,
          sessionCardId: item.sessionCardId,
          newMasteryLevel: masteryLevel,
          isFail: false,
          newPosition: null,
          newConsecutiveFails: 0,
          promptPark: false,
        ),
      );
    }

    // Fail: requeue behind the others, bump the counter.
    final rest = queue.sublist(1);
    final newPosition = requeuePosition(
      rest.map((i) => i.position).toList(),
      currentPosition: item.position,
    );
    final fails = item.consecutiveFails + 1;
    final requeued = item.copyWith(
      position: newPosition,
      consecutiveFails: fails,
      masteryLevel: masteryLevel,
      requeueCount: item.requeueCount + 1,
    );
    final newQueue = [...rest, requeued]
      ..sort((a, b) => a.position.compareTo(b.position));
    final promptPark = fails >= _parkThreshold;

    final next = _copy(
      queue: newQueue,
      phase: promptPark ? SessionPhase.parkPrompt : SessionPhase.studying,
      pendingParkSessionCardId: promptPark ? item.sessionCardId : null,
      clearPending: !promptPark,
    );
    return (
      state: next,
      effects: RatingEffects(
        cardId: item.cardId,
        sessionCardId: item.sessionCardId,
        newMasteryLevel: masteryLevel,
        isFail: true,
        newPosition: newPosition,
        newConsecutiveFails: fails,
        promptPark: promptPark,
      ),
    );
  }

  /// Parks the prompted card: drops it from the queue for good. Caller must
  /// ensure [phase] is [SessionPhase.parkPrompt].
  StudySessionState confirmPark() {
    assert(phase == SessionPhase.parkPrompt);
    final parked = queue.firstWhere(
      (i) => i.sessionCardId == pendingParkSessionCardId,
    );
    final newQueue = queue
        .where((i) => i.sessionCardId != pendingParkSessionCardId)
        .toList();
    return _copy(
      queue: newQueue,
      parkedCardIds: {...parkedCardIds, parked.cardId},
      phase: newQueue.isEmpty ? SessionPhase.completed : SessionPhase.studying,
      clearPending: true,
    );
  }

  /// Declines the park: the card stays, with its consecutive-fail counter reset
  /// to zero (a fresh three-fail budget). Caller must ensure [phase] is
  /// [SessionPhase.parkPrompt].
  StudySessionState declinePark() {
    assert(phase == SessionPhase.parkPrompt);
    final newQueue = [
      for (final i in queue)
        if (i.sessionCardId == pendingParkSessionCardId)
          i.copyWith(consecutiveFails: 0)
        else
          i,
    ];
    return _copy(
      queue: newQueue,
      phase: SessionPhase.studying,
      clearPending: true,
    );
  }

  static const int _parkThreshold = 3;

  /// Attaches the finished-session [SessionOutcome] (spec §7). Called by the
  /// controller on the transition into [SessionPhase.completed].
  StudySessionState withOutcome(SessionOutcome outcome) =>
      _copy(outcome: outcome);

  StudySessionState _copy({
    List<StudyQueueItem>? queue,
    Set<String>? masteredCardIds,
    Set<String>? parkedCardIds,
    SessionPhase? phase,
    String? pendingParkSessionCardId,
    bool clearPending = false,
    SessionOutcome? outcome,
    Map<StudyAttemptId, StudyAttemptMetadata>? attemptMetadata,
  }) {
    final nextQueue = queue ?? this.queue;
    return StudySessionState(
      session: session,
      deckId: deckId,
      deckName: deckName,
      queue: List.unmodifiable(nextQueue),
      masteredCardIds: masteredCardIds ?? this.masteredCardIds,
      parkedCardIds: parkedCardIds ?? this.parkedCardIds,
      totalCards: totalCards,
      phase: phase ?? this.phase,
      pendingParkSessionCardId: clearPending
          ? null
          : (pendingParkSessionCardId ?? this.pendingParkSessionCardId),
      attemptMetadata: Map.unmodifiable(
        attemptMetadata ?? this.attemptMetadata,
      ),
      outcome: outcome ?? this.outcome,
    );
  }
}
