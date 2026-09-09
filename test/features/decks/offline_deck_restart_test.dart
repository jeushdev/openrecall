import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/session_card.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';
import 'package:path/path.dart' as p;

import '../../support/local_db_harness.dart';

FlashCard _card(String id) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: 'Question $id',
  back: 'Answer $id',
  keywords: const ['offline'],
  isConcept: true,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

StudySession _completedSession() => StudySession(
  id: 'session-1',
  deckId: 'deck-1',
  status: SessionStatus.completed,
  studyMode: StudyMode.flip,
  lengthMode: SessionLengthMode.untilMastered,
  cappedLength: null,
  cardScope: CardScope.due,
  masteryDelta: 100,
  startedAt: DateTime.utc(2026),
  completedAt: DateTime.utc(2026, 1, 2),
);

void main() {
  setUpAll(initLocalDbTestFfi);

  late Directory directory;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('open_recall_m5_');
    databasePath = p.join(directory.path, 'explicit-offline-deck.sqlite');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('successful package remains explicitly available after database and provider recreation', () async {
    final first = await openNamedTestDatabase(databasePath);
    await LocalDeckStore(first.db).commitDeckPackage(
      deckId: 'deck-1',
      deckName: 'Restartable biology',
      cards: [_card('card-1'), _card('card-2')],
      pin: true,
    );
    await first.close();

    final reopened = await openNamedTestDatabase(databasePath);
    addTearDown(reopened.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(reopened)],
    );
    addTearDown(container.dispose);

    final status = await container.read(
      offlinePackageStatusProvider('deck-1').future,
    );
    expect(status.isExplicitlyAvailable, isTrue);
    expect(status.cardsComplete, isTrue);
    expect(
      (await container.read(localDeckStoreProvider).cards('deck-1'))
          .map((card) => card.id),
      ['card-1', 'card-2'],
    );
  });

  test(
    'failed incomplete package never becomes available after restart',
    () async {
      final first = await openNamedTestDatabase(databasePath);
      final store = LocalDeckStore(first.db);
      await store.pinDeck(deckId: 'deck-1', name: 'Interrupted download');
      await expectLater(
        store.commitDeckPackage(
          deckId: 'deck-1',
          cards: [_card('duplicate'), _card('duplicate')],
          pin: true,
        ),
        throwsStateError,
      );
      await first.close();

      final reopened = await openNamedTestDatabase(databasePath);
      addTearDown(reopened.close);
      final status = await LocalDeckStore(reopened.db).packageStatus('deck-1');
      expect(status.availability, OfflinePackageAvailability.incomplete);
      expect(status.isExplicitlyAvailable, isFalse);
      expect(await LocalDeckStore(reopened.db).cards('deck-1'), isEmpty);
    },
  );

  test('clean removal remains removed after restart', () async {
    final first = await openNamedTestDatabase(databasePath);
    final store = LocalDeckStore(first.db);
    await store.commitDeckPackage(
      deckId: 'deck-1',
      deckName: 'Removable',
      cards: [_card('card-1')],
      pin: true,
    );
    await store.removeDeck('deck-1');
    await first.close();

    final reopened = await openNamedTestDatabase(databasePath);
    addTearDown(reopened.close);
    final restored = LocalDeckStore(reopened.db);
    expect(
      (await restored.packageStatus('deck-1')).availability,
      OfflinePackageAvailability.suppressed,
    );
    expect(await restored.cards('deck-1'), isEmpty);
  });

  test('removal retains pending study work across restart while clearing usable package', () async {
    final first = await openNamedTestDatabase(databasePath);
    final decks = LocalDeckStore(first.db);
    final study = LocalStudyStore(first.db);
    await decks.commitDeckPackage(
      deckId: 'deck-1',
      deckName: 'Pending results',
      cards: [_card('protected'), _card('discardable')],
      pin: true,
    );
    await study.insertSession(_completedSession(), 'user-1', synced: false);
    await study.insertSessionCards(const [
      SessionCard(
        id: 'queue-1',
        sessionId: 'session-1',
        cardId: 'protected',
        position: 0,
        consecutiveFails: 0,
        isParked: false,
      ),
    ], synced: false);
    await decks.removeDeck('deck-1');
    await first.close();

    final reopened = await openNamedTestDatabase(databasePath);
    addTearDown(reopened.close);
    final restoredDecks = LocalDeckStore(reopened.db);
    final restoredStudy = LocalStudyStore(reopened.db);
    expect(
      (await restoredDecks.packageStatus('deck-1')).isUsableOffline,
      isFalse,
    );
    expect(await restoredDecks.cardById('protected'), isNotNull);
    expect(await restoredDecks.cardById('discardable'), isNull);
    expect((await restoredStudy.unsyncedSessions()).single.id, 'session-1');
    expect((await restoredStudy.unsyncedSessionCards()).single.id, 'queue-1');
  });
}
