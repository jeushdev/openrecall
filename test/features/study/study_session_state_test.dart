import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_queue_item.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/domain/study_session_state.dart';

FlashCard _card(String id) => FlashCard(
      id: id,
      deckId: 'deck-1',
      front: 'front-$id',
      back: 'back-$id',
      keyword: null,
      masteryLevel: 0,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

StudySession _session({
  SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
  int? cappedLength,
}) =>
    StudySession(
      id: 'session-1',
      deckId: 'deck-1',
      status: SessionStatus.active,
      studyMode: StudyMode.flip,
      lengthMode: lengthMode,
      cappedLength: cappedLength,
      masteryDelta: null,
      startedAt: DateTime.utc(2026),
      completedAt: null,
    );

StudySessionState _stateWith(
  List<String> cardIds, {
  SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
  int? cappedLength,
}) {
  final items = [
    for (var i = 0; i < cardIds.length; i++)
      StudyQueueItem(
        sessionCardId: 'sc-${cardIds[i]}',
        card: _card(cardIds[i]),
        position: (i + 1) * 1000,
        consecutiveFails: 0,
        isParked: false,
        masteryLevel: 0,
      ),
  ];
  return StudySessionState.initial(
    session: _session(lengthMode: lengthMode, cappedLength: cappedLength),
    deckId: 'deck-1',
    deckName: 'Biology',
    items: items,
  );
}

void main() {
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
      final requeued =
          result.state.queue.firstWhere((i) => i.cardId == 'a');
      expect(requeued.consecutiveFails, 1);
      expect(requeued.masteryLevel, 1);
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
      final afterPass = state.applyRating(FlipRating.mastered).state; // a mastered
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
    test('an uncapped session with one stubborn card never completes until parked',
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
    });

    test('completes once every card is mastered', () {
      var state = _stateWith(['a', 'b']);
      state = state.applyRating(FlipRating.mastered).state;
      state = state.applyRating(FlipRating.mastered).state;
      expect(state.phase, SessionPhase.completed);
      expect(state.resolvedCount, 2);
    });
  });

  group('capped sessions', () {
    test('a cap-2 session completes after those two cards regardless of the deck',
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
    });
  });
}
