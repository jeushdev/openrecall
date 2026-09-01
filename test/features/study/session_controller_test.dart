import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:open_recall/features/study/domain/study_session_state.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

FlashCard _card(
  String id, {
  int mastery = 0,
  int fails = 0,
  List<String> keywords = const [],
  bool isConcept = false,
}) =>
    FlashCard(
      id: id,
      deckId: 'deck-1',
      front: 'front-$id',
      back: 'back-$id',
      keywords: keywords,
      isConcept: isConcept,
      masteryLevel: mastery,
      failCount: fails,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late FakeDeckRepository decks;
  late FakeStudyRepository study;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          deckRepositoryProvider.overrideWithValue(decks),
          studyRepositoryProvider.overrideWithValue(study),
        ],
      );

  setUp(() {
    decks = FakeDeckRepository();
    study = FakeStudyRepository();
  });

  tearDown(() => container.dispose());

  SessionController controller() =>
      container.read(sessionControllerProvider.notifier);
  StudySessionState state() =>
      container.read(sessionControllerProvider).value!;

  Future<void> start({
    SessionLengthMode lengthMode = SessionLengthMode.untilMastered,
    int? cap,
    CardScope cardScope = CardScope.due,
  }) =>
      controller().start(
        deckId: 'deck-1',
        deckName: 'Biology',
        mode: StudyMode.flip,
        lengthMode: lengthMode,
        cap: cap,
        cardScope: cardScope,
      );

  group('start', () {
    test('abandons an existing active session before creating the new one',
        () async {
      decks = FakeDeckRepository(cards: [_card('a')]);
      study = FakeStudyRepository();
      container = makeContainer();
      await study.createSession(
        deckId: 'deck-1',
        studyMode: StudyMode.flip,
        lengthMode: SessionLengthMode.untilMastered,
      );
      study.calls.clear();

      await start();

      final abandonIndex = study.calls
          .indexWhere((c) => c.startsWith('abandonActiveSessions'));
      final createIndex =
          study.calls.indexWhere((c) => c.startsWith('createSession'));
      expect(abandonIndex, isNonNegative);
      expect(createIndex, greaterThan(abandonIndex));
      expect(study.sessions.first.status, SessionStatus.abandoned);
    });

    test('creates a flip session and seeds only due cards with sparse positions',
        () async {
      decks = FakeDeckRepository(cards: [
        _card('a'),
        _card('m', mastery: 4),
        _card('b'),
      ]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();

      expect(study.calls, contains(startsWith('createSession(deck=deck-1, '
          'mode=flip, length=uncapped')));
      final session = study.sessions.single;
      final cards = study.sessionCardsFor(session.id);
      expect(cards.map((c) => c.cardId), ['a', 'b']);
      expect(cards.map((c) => c.position), [1000, 2000]);
      expect(state().totalCards, 2);
      expect(state().current!.cardId, 'a');
    });

    test('applies the cap after filtering out mastered cards', () async {
      decks = FakeDeckRepository(cards: [
        _card('m', mastery: 4),
        _card('a'),
        _card('b'),
        _card('c'),
      ]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start(lengthMode: SessionLengthMode.capped, cap: 2);

      expect(study.sessionCardsFor(study.sessions.single.id).map((c) => c.cardId),
          ['a', 'b']);
      expect(study.sessions.single.cappedLength, 2);
    });

    test('marks the deck studied on start', () async {
      decks = FakeDeckRepository(cards: [_card('a')]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();

      expect(decks.calls, contains('markDeckStudied(deck-1)'));
    });

    test('an all-mastered deck errors without creating a session', () async {
      decks = FakeDeckRepository(cards: [_card('a', mastery: 4)]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();

      expect(container.read(sessionControllerProvider).hasError, isTrue);
      expect(study.calls.any((c) => c.startsWith('createSession')), isFalse);
    });

    test('starting again for the same live session is a no-op', () async {
      decks = FakeDeckRepository(cards: [_card('a')]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();
      study.calls.clear();
      await start();

      expect(study.calls, isEmpty);
    });

    test('a default (due-scoped) session records card_scope = due', () async {
      decks = FakeDeckRepository(cards: [_card('a')]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();

      expect(study.sessions.single.cardScope, CardScope.due);
    });
  });

  group('start — CardScope.all', () {
    test(
        'seeds a non-empty queue from a fully-mastered deck and records '
        'card_scope = all', () async {
      decks = FakeDeckRepository(cards: [
        _card('a', mastery: 4),
        _card('b', mastery: 4),
        _card('c', mastery: 4),
      ]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start(cardScope: CardScope.all);

      final session = study.sessions.single;
      expect(session.cardScope, CardScope.all);
      expect(
        study.sessionCardsFor(session.id).map((c) => c.cardId),
        ['a', 'b', 'c'],
      );
      expect(state().totalCards, 3);
    });

    test('a due-scoped session on the same fully-mastered deck errors', () async {
      decks = FakeDeckRepository(cards: [
        _card('a', mastery: 4),
        _card('b', mastery: 4),
      ]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start();

      expect(container.read(sessionControllerProvider).hasError, isTrue);
      expect(study.calls.any((c) => c.startsWith('createSession')), isFalse);
    });

    test('a Mastered card rated below 4 requeues and its mastery_level drops',
        () async {
      decks = FakeDeckRepository(cards: [_card('a', mastery: 4)]);
      study = FakeStudyRepository();
      container = makeContainer();

      await start(cardScope: CardScope.all);
      controller().rate(FlipRating.forgotten);
      await pumpEventQueue();

      expect(state().queue.any((i) => i.cardId == 'a'), isTrue);
      expect(decks.cardById('a')!.masteryLevel, 1);
      expect(decks.cardById('a')!.failCount, 1);
    });
  });

  group('rate', () {
    setUp(() {
      decks = FakeDeckRepository(cards: [_card('a'), _card('b')]);
      study = FakeStudyRepository();
      container = makeContainer();
    });

    test('advances the queue synchronously, before any write confirms',
        () async {
      await start();
      controller().rate(FlipRating.mastered);
      // no await here — the optimistic state must already have moved on
      expect(state().current!.cardId, 'b');
      expect(state().masteredCardIds, {'a'});

      await pumpEventQueue();
      expect(decks.cardById('a')!.masteryLevel, 4);
    });

    test('a fail keeps the card, requeues it, and writes the session_card',
        () async {
      await start();
      controller().rate(FlipRating.forgotten);
      await pumpEventQueue();

      expect(state().queue.any((i) => i.cardId == 'a'), isTrue);
      expect(decks.cardById('a')!.failCount, 1);
      expect(
        study.calls,
        contains(startsWith(
            'updateSessionCard(id=sc-1, position=3000, consecutiveFails=1')),
      );
    });

    test('a re-rate before the first write confirms does not lose the update',
        () async {
      await start();
      decks.guardGate = Completer<void>();

      controller().rate(FlipRating.forgotten); // a -> fail, write A (gated)
      controller().rate(FlipRating.mastered); // b mastered
      // a is current again
      expect(state().current!.cardId, 'a');
      controller().rate(FlipRating.mastered); // a mastered, write B (gated)

      decks.guardGate!.complete();
      await pumpEventQueue();

      expect(decks.cardById('a')!.masteryLevel, 4);
      expect(decks.cardById('a')!.failCount, 1); // exactly one lifetime increment
    });

    test('a guard miss re-reads and retries the write once', () async {
      await start();
      decks.failNextGuard = true;

      controller().rate(FlipRating.forgotten);
      await pumpEventQueue();

      expect(decks.calls, contains(startsWith('readCardMasteryState')));
      expect(decks.cardById('a')!.masteryLevel, 1);
      expect(decks.cardById('a')!.failCount, 1);
    });
  });

  group('park', () {
    setUp(() {
      decks = FakeDeckRepository(cards: [_card('a'), _card('b')]);
      study = FakeStudyRepository();
      container = makeContainer();
    });

    Future<void> failToPrompt() async {
      await start();
      controller().rate(FlipRating.forgotten); // a: 1
      controller().rate(FlipRating.mastered); // b done
      controller().rate(FlipRating.forgotten); // a: 2
      controller().rate(FlipRating.forgotten); // a: 3 -> prompt
      await pumpEventQueue();
    }

    test('the third consecutive fail moves the phase to parkPrompt', () async {
      await failToPrompt();
      expect(state().phase, SessionPhase.parkPrompt);
    });

    test('confirmPark writes is_parked and can complete the session', () async {
      await failToPrompt();
      controller().confirmPark();
      await pumpEventQueue();

      expect(
        study.calls,
        contains(startsWith('updateSessionCard(id=sc-1')),
      );
      final parkedRow = study.sessionCardById('sc-1');
      expect(parkedRow!.isParked, isTrue);
      expect(state().phase, SessionPhase.completed);
    });

    test('declinePark resets the counter and writes consecutive_fails 0',
        () async {
      await failToPrompt();
      controller().declinePark();
      await pumpEventQueue();

      expect(state().phase, SessionPhase.studying);
      expect(
        study.calls,
        contains(startsWith(
            'updateSessionCard(id=sc-1, position=null, consecutiveFails=0')),
      );
    });
  });

  group('completion and exit', () {
    setUp(() {
      decks = FakeDeckRepository(cards: [_card('a')]);
      study = FakeStudyRepository();
      container = makeContainer();
    });

    test('completing the queue flushes mastery writes before completeSession',
        () async {
      await start();
      decks.guardGate = Completer<void>();

      controller().rate(FlipRating.mastered);
      await pumpEventQueue();
      // the mastery write is gated open — completeSession must wait for it
      expect(study.calls.any((c) => c.startsWith('completeSession')), isFalse);

      decks.guardGate!.complete();
      await pumpEventQueue();

      expect(study.calls, contains(startsWith('completeSession')));
      expect(decks.cardById('a')!.masteryLevel, 4);
      expect(study.sessions.single.status, SessionStatus.completed);
      expect(study.sessions.single.completedAt, isNotNull);
    });

    test('completing a session records how many cards it reviewed', () async {
      await start();

      controller().rate(FlipRating.mastered);
      await pumpEventQueue();

      expect(
        study.calls,
        contains(startsWith('completeSession(session-1, masteryDelta=')),
      );
      expect(
        study.calls.singleWhere((c) => c.startsWith('completeSession')),
        endsWith('cardsReviewed=1)'),
      );
    });

    test('exit leaves the session active and keeps the state for resume',
        () async {
      await start();
      controller().rate(FlipRating.forgotten);
      controller().exit();
      await pumpEventQueue();

      expect(study.calls.any((c) => c.startsWith('completeSession')), isFalse);
      expect(study.sessions.single.status, SessionStatus.active);
      expect(container.read(sessionControllerProvider).value, isNotNull);
    });
  });
}
