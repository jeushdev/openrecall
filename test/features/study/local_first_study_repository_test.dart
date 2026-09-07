import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/data/cache_first_study_repository.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/queue_seed.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';
import '../../support/local_db_harness.dart';

FlashCard _card() => FlashCard(
  id: 'card-1',
  deckId: 'deck-1',
  front: 'Question',
  back: 'Answer',
  keywords: const ['Question'],
  isConcept: true,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'complete packages commit every study mutation without touching remote',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final decks = LocalDeckStore(database.db);
      final study = LocalStudyStore(database.db);
      await decks.commitDeckPackage(
        deckId: 'deck-1',
        deckName: 'Biology',
        cards: [_card()],
      );
      await study.insertSession(
        StudySession(
          id: 'old-session',
          deckId: 'deck-1',
          status: SessionStatus.active,
          studyMode: StudyMode.flip,
          lengthMode: SessionLengthMode.untilMastered,
          cappedLength: null,
          cardScope: CardScope.due,
          masteryDelta: null,
          startedAt: DateTime.utc(2026),
          completedAt: null,
        ),
        'user-1',
        synced: true,
      );
      final remote = FakeStudyRepository()
        ..writeGate = Completer<void>(); // every remote mutation would stall
      final repository = CacheFirstStudyRepository(
        remote,
        study,
        decks,
        () => 'user-1',
      );

      await repository
          .abandonActiveSessions('deck-1')
          .timeout(const Duration(milliseconds: 100));
      final session = await repository
          .createSession(
            deckId: 'deck-1',
            studyMode: StudyMode.cloze,
            lengthMode: SessionLengthMode.untilMastered,
          )
          .timeout(const Duration(milliseconds: 100));
      final queue = await repository
          .createSessionCards(session.id, const [
            QueueSeed(cardId: 'card-1', position: 1000),
          ])
          .timeout(const Duration(milliseconds: 100));
      await repository
          .updateSessionCard(
            sessionCardId: queue.single.id,
            position: 2000,
            consecutiveFails: 1,
            isParked: true,
          )
          .timeout(const Duration(milliseconds: 100));
      await repository
          .completeSession(session.id, masteryDelta: 100, cardsReviewed: 1)
          .timeout(const Duration(milliseconds: 100));

      expect(remote.calls, isEmpty);
      final dirtySessions = await study.unsyncedSessions();
      expect(dirtySessions, hasLength(2));
      expect(
        dirtySessions
            .singleWhere((row) => row.id == 'old-session')
            .values['status'],
        'abandoned',
      );
      final completed = dirtySessions.singleWhere(
        (row) => row.id == session.id,
      );
      expect(completed.values['status'], 'completed');
      expect(completed.values['mastery_delta'], 100);
      expect(completed.values['cards_reviewed'], 1);
      final dirtyQueue = (await study.unsyncedSessionCards()).single;
      expect(dirtyQueue.values['position'], 2000);
      expect(dirtyQueue.values['consecutive_fails'], 1);
      expect(dirtyQueue.values['is_parked'], isTrue);
    },
  );

  test(
    'complete packages commit mastery and last-studied before remote work',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final local = LocalDeckStore(database.db);
      final original = _card();
      await local.commitDeckPackage(
        deckId: 'deck-1',
        deckName: 'Biology',
        cards: [original],
      );
      final remote = FakeDeckRepository(cards: [original])
        ..guardGate = Completer<void>();
      final repository = CacheFirstDeckRepository(
        remote,
        local,
        LocalCourseStore(database.db),
      );

      final updated = await repository
          .updateCardMasteryGuarded(
            cardId: original.id,
            masteryLevel: 4,
            failCount: 0,
            expectedUpdatedAt: original.updatedAt,
          )
          .timeout(const Duration(milliseconds: 100));
      await repository
          .markDeckStudied('deck-1')
          .timeout(const Duration(milliseconds: 100));

      expect(updated!.masteryLevel, 4);
      expect(remote.calls, isEmpty);
      expect((await local.unsyncedCards()).single.masteryLevel, 4);
      expect((await local.unsyncedDecks()).single.lastStudiedAt, isNotNull);
    },
  );

  test('without SQLite the study repositories remain online-only', () async {
    final remoteStudy = FakeStudyRepository();
    final study = CacheFirstStudyRepository(
      remoteStudy,
      LocalStudyStore(null),
      LocalDeckStore(null),
      () => 'user-1',
    );
    final remoteDeck = FakeDeckRepository(cards: [_card()]);
    final decks = CacheFirstDeckRepository(
      remoteDeck,
      LocalDeckStore(null),
      LocalCourseStore(null),
    );

    final session = await study.createSession(
      deckId: 'deck-1',
      studyMode: StudyMode.flip,
      lengthMode: SessionLengthMode.untilMastered,
    );
    final mastery = await decks.updateCardMasteryGuarded(
      cardId: 'card-1',
      masteryLevel: 4,
      failCount: 0,
      expectedUpdatedAt: _card().updatedAt,
    );
    await decks.markDeckStudied('deck-1');

    expect(session.id, 'session-1');
    expect(mastery!.masteryLevel, 4);
    expect(remoteStudy.calls, contains(startsWith('createSession')));
    expect(remoteDeck.calls, contains(startsWith('updateCardMasteryGuarded')));
    expect(remoteDeck.calls, contains('markDeckStudied(deck-1)'));
  });
}
