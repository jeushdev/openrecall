import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_attempt.dart';
import 'package:open_recall/features/study/domain/study_queue_item.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/domain/study_session_state.dart';

FlashCard _card(String id, {int historicalFails = 0}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: 'front-$id',
  back: 'back-$id',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: historicalFails,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

StudySession _session({
  SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
  int? cappedLength,
  CardScope cardScope = CardScope.due,
}) => StudySession(
  id: 'session-1',
  deckId: 'deck-1',
  status: SessionStatus.active,
  studyMode: StudyMode.flip,
  lengthMode: lengthMode,
  cappedLength: cappedLength,
  cardScope: cardScope,
  masteryDelta: null,
  startedAt: DateTime.utc(2026),
  completedAt: null,
);

StudySessionState _stateWith(
  List<String> cardIds, {
  SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
  int? cappedLength,
  CardScope cardScope = CardScope.due,
  int seededMastery = 0,
}) {
  final items = [
    for (var i = 0; i < cardIds.length; i++)
      StudyQueueItem(
        sessionCardId: 'sc-${cardIds[i]}',
        card: _card(cardIds[i]),
        position: (i + 1) * 1000,
        consecutiveFails: 0,
        isParked: false,
        masteryLevel: seededMastery,
      ),
  ];
  return StudySessionState.initial(
    session: _session(
      lengthMode: lengthMode,
      cappedLength: cappedLength,
      cardScope: cardScope,
    ),
    deckId: 'deck-1',
    deckName: 'Biology',
    items: items,
  );
}

void main() {
  group('attempt metadata', () {
    test('records false activity and merges hint usage with logical OR', () {
      var state = _stateWith(['a']);
      final attempt = state.currentAttemptId!;

      state = state.recordAttemptMetadata(attempt, hintUsed: false);
      expect(state.attemptMetadata[attempt]?.hintUsed, isFalse);
      state = state.recordAttemptMetadata(attempt, hintUsed: true);
      state = state.recordAttemptMetadata(attempt, hintUsed: false);
      expect(state.attemptMetadata[attempt]?.hintUsed, isTrue);
    });

    test('rejects metadata for an attempt that is no longer active', () {
      var state = _stateWith(['a', 'b']);
      final stale = state.currentAttemptId!;
      state = state.applyRating(FlipRating.mastered).state;

      final unchanged = state.recordAttemptMetadata(stale, hintUsed: true);
      expect(identical(unchanged, state), isTrue);
      expect(unchanged.attemptMetadata, isEmpty);
    });

    test('retains metadata after completion', () {
      var state = _stateWith(['a']);
      final attempt = state.currentAttemptId!;
      state = state.recordAttemptMetadata(attempt, hintUsed: true);
      state = state.applyRating(FlipRating.mastered).state;

      expect(state.isComplete, isTrue);
      expect(state.attemptMetadata[attempt]?.hintUsed, isTrue);
    });

    test('retains older attempt metadata after parking', () {
      var state = _stateWith(['a']);
      final assisted = state.currentAttemptId!;
      state = state.recordAttemptMetadata(assisted, hintUsed: true);
      state = state.applyRating(FlipRating.forgotten).state;
      state = state.applyRating(FlipRating.forgotten).state;
      state = state.applyRating(FlipRating.forgotten).state;

      state = state.confirmPark();

      expect(state.isComplete, isTrue);
      expect(state.attemptMetadata[assisted]?.hintUsed, isTrue);
    });

    test('a requeue creates a fresh unassisted attempt identity', () {
      var state = _stateWith(['a']);
      final first = state.currentAttemptId!;
      state = state.recordAttemptMetadata(first, hintUsed: true);
      state = state.applyRating(FlipRating.forgotten).state;

      expect(state.currentAttemptId, isNot(first));
      expect(state.hintUsedFor(state.currentAttemptId!), isFalse);
      expect(state.hintUsedFor(first), isTrue);
    });

    test('attempt identity includes all three planned components', () {
      const a = StudyAttemptId(
        sessionId: 's',
        sessionCardId: 'sc',
        queuePosition: 1000,
      );
      const retry = StudyAttemptId(
        sessionId: 's',
        sessionCardId: 'sc',
        queuePosition: 2000,
      );
      expect(a, isNot(retry));
    });
  });

  group('initial state', () {
    test('current is the lowest-position card; queue is sorted', () {
      final state = _stateWith(['a', 'b', 'c']);
      expect(state.current!.cardId, 'a');
      expect(state.phase, SessionPhase.studying);
      expect(state.totalCards, 3);
      expect(state.resolvedCount, 0);
    });

    test('current is null and phase is completed when seeded empty', () {
      final state = _stateWith([]);
      expect(state.current, isNull);
      expect(state.phase, SessionPhase.completed);
    });

    test('historical failures do not make a fresh card returning', () {
      final item = StudyQueueItem(
        sessionCardId: 'sc-a',
        card: _card('a', historicalFails: 12),
        position: 1000,
        consecutiveFails: 0,
        isParked: false,
        masteryLevel: 0,
      );
      final state = StudySessionState.initial(
        session: _session(),
        deckId: 'deck-1',
        deckName: 'Biology',
        items: [item],
      );

      expect(state.currentCardAppearance, CardAppearance.firstAttempt);
    });

    test('freshly seeded cards start as first attempts', () {
      expect(
        _stateWith(['a', 'b']).queue.map((item) => item.requeueCount),
        everyElement(0),
      );
    });
  });

  group('applyRating — Mastered', () {
    test('removes the card from the queue and counts it mastered', () {
      final state = _stateWith(['a', 'b']);
      final result = state.applyRating(FlipRating.mastered);

      expect(result.state.queue.map((i) => i.cardId), ['b']);
      expect(result.state.masteredCardIds, {'a'});
      expect(result.state.current!.cardId, 'b');
      expect(result.effects.cardId, 'a');
      expect(result.effects.newMasteryLevel, 4);
      expect(result.effects.isFail, isFalse);
      expect(result.effects.promptPark, isFalse);
      expect(result.effects.newPosition, isNull);
    });

    test('mastering the last card completes the session', () {
      final state = _stateWith(['a']);
      final result = state.applyRating(FlipRating.mastered);

      expect(result.state.phase, SessionPhase.completed);
      expect(result.state.isComplete, isTrue);
      expect(result.state.current, isNull);
    });
  });

  group('applyRating — fail', () {
    test('requeues the card behind the others and bumps consecutive_fails', () {
      final state = _stateWith(['a', 'b', 'c']);
      final result = state.applyRating(FlipRating.forgotten);

      expect(result.state.queue.first.cardId, 'b');
      expect(result.state.queue.map((i) => i.cardId), ['b', 'c', 'a']);
      final requeued = result.state.queue.firstWhere((i) => i.cardId == 'a');
      expect(requeued.consecutiveFails, 1);
      expect(requeued.masteryLevel, 1);
      expect(requeued.requeueCount, 1);
      expect(result.state.currentCardAppearance, CardAppearance.firstAttempt);
      expect(result.effects.isFail, isTrue);
      expect(result.effects.newMasteryLevel, 1);
      expect(result.effects.newConsecutiveFails, 1);
      expect(result.effects.newPosition, isNotNull);
      expect(result.effects.promptPark, isFalse);
      expect(result.state.phase, SessionPhase.studying);
    });

    test('a fail never masters or parks — the card stays in the queue', () {
      final state = _stateWith(['a']);
      final result = state.applyRating(FlipRating.familiar);

      expect(result.state.queue.single.cardId, 'a');
      expect(result.state.phase, SessionPhase.studying);
      expect(result.state.isComplete, isFalse);
    });

    test('a one-card retry immediately becomes returning', () {
      final state = _stateWith(['a']);
      final retry = state.applyRating(FlipRating.forgotten).state;

      expect(retry.current!.cardId, 'a');
      expect(retry.current!.requeueCount, 1);
      expect(retry.currentCardAppearance, CardAppearance.returning);
    });

    test('each repeated retry keeps the returning appearance', () {
      var state = _stateWith(['a']);
      state = state.applyRating(FlipRating.forgotten).state;
      state = state.applyRating(FlipRating.familiar).state;

      expect(state.current!.requeueCount, 2);
      expect(state.currentCardAppearance, CardAppearance.returning);
    });

    test('the third consecutive fail raises the park prompt', () {
      var state = _stateWith(['a', 'b']);
      state = state.applyRating(FlipRating.forgotten).state; // a: 1
      // bring 'a' back to the front
      state = state.applyRating(FlipRating.mastered).state; // b mastered
      expect(state.current!.cardId, 'a');
      state = state.applyRating(FlipRating.forgotten).state; // a: 2
      final result = state.applyRating(FlipRating.forgotten); // a: 3

      expect(result.state.phase, SessionPhase.parkPrompt);
      expect(result.state.pendingParkSessionCardId, 'sc-a');
      expect(result.effects.promptPark, isTrue);
      // still requeued, not yet removed
      expect(result.state.queue.any((i) => i.cardId == 'a'), isTrue);
    });

    test('a later Mastered still resolves a card that failed twice', () {
      var state = _stateWith(['a', 'b']);
      state = state.applyRating(FlipRating.forgotten).state; // a: 1
      state = state.applyRating(FlipRating.mastered).state; // b mastered
      state = state.applyRating(FlipRating.forgotten).state; // a: 2
      final afterPass = state
          .applyRating(FlipRating.mastered)
          .state; // a mastered
      expect(afterPass.masteredCardIds, contains('a'));
      expect(afterPass.phase, SessionPhase.completed);
    });
  });

  group('park', () {
    StudySessionState parkPrompted() {
      var state = _stateWith(['a', 'b']);
      state = state.applyRating(FlipRating.forgotten).state;
      state = state.applyRating(FlipRating.mastered).state; // b mastered
      state = state.applyRating(FlipRating.forgotten).state;
      state = state.applyRating(FlipRating.forgotten).state; // a: 3 -> prompt
      return state;
    }

    test('confirmPark removes the card and marks it parked', () {
      final state = parkPrompted().confirmPark();
      expect(state.queue.any((i) => i.cardId == 'a'), isFalse);
      expect(state.parkedCardIds, {'a'});
      expect(state.pendingParkSessionCardId, isNull);
      // b was already mastered, a now parked -> session done
      expect(state.phase, SessionPhase.completed);
      expect(state.resolvedCount, 2);
    });

    test('declinePark resets the counter and resumes studying', () {
      final state = parkPrompted().declinePark();
      expect(state.phase, SessionPhase.studying);
      expect(state.pendingParkSessionCardId, isNull);
      final a = state.queue.firstWhere((i) => i.cardId == 'a');
      expect(a.consecutiveFails, 0);
      expect(a.requeueCount, 3);
      expect(state.currentCardAppearance, CardAppearance.returning);
    });

    test('after declining, it takes three more fails to be prompted again', () {
      var state = parkPrompted().declinePark();
      state = state.applyRating(FlipRating.forgotten).state; // 1
      state = state.applyRating(FlipRating.forgotten).state; // 2
      expect(state.phase, SessionPhase.studying);
      state = state.applyRating(FlipRating.forgotten).state; // 3
      expect(state.phase, SessionPhase.parkPrompt);
    });
  });

  group('termination', () {
    test(
      'an uncapped session with one stubborn card never completes until parked',
      () {
        var state = _stateWith(['a']);
        for (var i = 0; i < 10; i++) {
          final result = state.applyRating(FlipRating.forgotten);
          state = result.state;
          expect(state.isComplete, isFalse);
          if (state.phase == SessionPhase.parkPrompt) {
            state = state.declinePark();
          }
        }
        // fail to the prompt, then park
        while (state.phase != SessionPhase.parkPrompt) {
          state = state.applyRating(FlipRating.forgotten).state;
        }
        state = state.confirmPark();
        expect(state.phase, SessionPhase.completed);
      },
    );

    test('completes once every card is mastered', () {
      var state = _stateWith(['a', 'b']);
      state = state.applyRating(FlipRating.mastered).state;
      state = state.applyRating(FlipRating.mastered).state;
      expect(state.phase, SessionPhase.completed);
      expect(state.resolvedCount, 2);
    });
  });

  group('card scope', () {
    test('the session carries its CardScope through initial state', () {
      final state = _stateWith(['a'], cardScope: CardScope.all);
      expect(state.session.cardScope, CardScope.all);
    });

    test('the loop is scope-agnostic: an already-Mastered card rated below 4 '
        'still requeues and regresses', () {
      final state = _stateWith(
        ['a', 'b'],
        cardScope: CardScope.all,
        seededMastery: 4,
      );
      final result = state.applyRating(FlipRating.forgotten);

      expect(result.state.queue.any((i) => i.cardId == 'a'), isTrue);
      final requeued = result.state.queue.firstWhere((i) => i.cardId == 'a');
      expect(requeued.masteryLevel, 1);
      expect(requeued.consecutiveFails, 1);
      expect(result.effects.isFail, isTrue);
      expect(result.effects.newMasteryLevel, 1);
    });
  });

  group('capped sessions', () {
    test(
      'a cap-2 session completes after those two cards regardless of the deck',
      () {
        // Only 2 items were seeded (the cap was applied before seeding).
        var state = _stateWith(
          ['a', 'b'],
          lengthMode: SessionLengthMode.capped,
          cappedLength: 2,
        );
        expect(state.totalCards, 2);
        state = state.applyRating(FlipRating.mastered).state;
        state = state.applyRating(FlipRating.mastered).state;
        expect(state.phase, SessionPhase.completed);
      },
    );
  });
}
