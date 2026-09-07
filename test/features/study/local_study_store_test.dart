import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/session_card.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/local_db_harness.dart';

StudySession _session(String id) => StudySession(
  id: id,
  deckId: 'deck-1',
  status: SessionStatus.active,
  studyMode: StudyMode.flip,
  lengthMode: SessionLengthMode.untilMastered,
  cappedLength: null,
  cardScope: CardScope.due,
  masteryDelta: null,
  startedAt: DateTime.utc(2026),
  completedAt: null,
);

void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalStudyStore store;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    store = LocalStudyStore(database.db);
  });

  test(
    'a late session acknowledgment cannot clear a newer completion',
    () async {
      await store.insertSession(_session('session-1'), 'user-1', synced: false);
      final sent = (await store.unsyncedSessions()).single;

      await store.completeSession('session-1', 75, 3, synced: false);
      await store.markSessionsSynced([sent]);

      final stillDirty = (await store.unsyncedSessions()).single;
      expect(stillDirty.values['status'], 'completed');
      expect(stillDirty.values['mastery_delta'], 75);
      expect(stillDirty.values['cards_reviewed'], 3);
    },
  );

  test(
    'a late queue acknowledgment cannot clear a newer park decision',
    () async {
      await store.insertSession(_session('session-1'), 'user-1', synced: false);
      await store.insertSessionCards(const [
        SessionCard(
          id: 'queue-1',
          sessionId: 'session-1',
          cardId: 'card-1',
          position: 1000,
          consecutiveFails: 0,
          isParked: false,
        ),
      ], synced: false);
      final sent = (await store.unsyncedSessionCards()).single;

      await store.updateSessionCard(
        'queue-1',
        position: 2000,
        consecutiveFails: 3,
        isParked: true,
        synced: false,
      );
      await store.markSessionCardsSynced([sent]);

      final stillDirty = (await store.unsyncedSessionCards()).single;
      expect(stillDirty.values['position'], 2000);
      expect(stillDirty.values['consecutive_fails'], 3);
      expect(stillDirty.values['is_parked'], isTrue);
    },
  );

  test(
    'an acknowledgment of the sent revisions clears them exactly once',
    () async {
      await store.insertSession(_session('session-1'), 'user-1', synced: false);
      await store.insertSessionCards(const [
        SessionCard(
          id: 'queue-1',
          sessionId: 'session-1',
          cardId: 'card-1',
          position: 1000,
          consecutiveFails: 0,
          isParked: false,
        ),
      ], synced: false);
      final sessions = await store.unsyncedSessions();
      final queue = await store.unsyncedSessionCards();

      await store.markSessionsSynced(sessions);
      await store.markSessionCardsSynced(queue);
      await store.markSessionsSynced(sessions);
      await store.markSessionCardsSynced(queue);

      expect(await store.unsyncedSessions(), isEmpty);
      expect(await store.unsyncedSessionCards(), isEmpty);
    },
  );

  test(
    'a late mastery acknowledgment preserves the newer local rating',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final decks = LocalDeckStore(database.db);
      final original = FlashCard(
        id: 'card-1',
        deckId: 'deck-1',
        front: 'Question',
        back: 'Answer',
        keywords: const [],
        isConcept: false,
        masteryLevel: 0,
        failCount: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await decks.commitDeckPackage(
        deckId: 'deck-1',
        deckName: 'Biology',
        cards: [original],
      );
      final first = await decks.writeCardMasteryUnsynced(
        cardId: 'card-1',
        masteryLevel: 1,
        failCount: 1,
        expectedUpdatedAt: original.updatedAt,
      );
      final sent = (await decks.unsyncedCards()).single;
      await decks.writeCardMasteryUnsynced(
        cardId: 'card-1',
        masteryLevel: 4,
        failCount: 1,
        expectedUpdatedAt: first!.updatedAt,
      );

      await decks.markCardSynced(
        sent.id,
        DateTime.utc(2026, 2),
        sentRevision: sent,
      );

      final stillDirty = (await decks.unsyncedCards()).single;
      expect(stillDirty.masteryLevel, 4);
      expect(stillDirty.failCount, 1);
    },
  );
}
