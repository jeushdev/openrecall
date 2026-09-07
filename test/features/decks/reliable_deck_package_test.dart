import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';

import '../../support/local_db_harness.dart';

FlashCard _card(String id, {String front = 'Q'}) => FlashCard(
  id: id,
  deckId: 'd1',
  front: front,
  back: 'A',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase database;
  late LocalDeckStore store;
  setUp(() async {
    database = await openTestDatabase();
    store = LocalDeckStore(database.db);
  });
  tearDown(() => database.close());

  test('invalid replacement leaves a prior package and pin intact', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Deck',
      cards: [_card('old')],
      pin: true,
    );

    await expectLater(
      store.commitDeckPackage(
        deckId: 'd1',
        cards: [_card('duplicate'), _card('duplicate')],
        pin: false,
      ),
      throwsStateError,
    );

    expect(await store.isCardSetComplete('d1'), isTrue);
    expect((await store.cards('d1')).single.id, 'old');
    expect(await store.pinnedDeckIds(), contains('d1'));
  });

  test('dirty cards and tombstones survive package replacement', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Deck',
      cards: [_card('dirty'), _card('deleted')],
      pin: true,
    );
    await store.updateCardContent(
      id: 'dirty',
      front: 'local edit',
      back: 'A',
      keywords: const [],
      isConcept: false,
    );
    await store.deleteCard('deleted');

    await store.commitDeckPackage(
      deckId: 'd1',
      cards: [
        _card('dirty', front: 'server'),
        _card('deleted'),
      ],
    );

    expect((await store.cardById('dirty'))!.front, 'local edit');
    expect(await store.cardById('deleted'), isNull);
    expect(
      (await store.cardDeletions()).map((e) => e.entityId),
      contains('deleted'),
    );
    expect(await store.isCardSetComplete('d1'), isTrue);
  });

  test(
    'unpin preserves history and cards needed by active or pending work',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('active'), _card('pending'), _card('clean')],
        pin: true,
      );
      await database.db.insert('offline_study_sessions', {
        'id': 's1',
        'deck_id': 'd1',
        'status': 'active',
        'study_mode': 'flip',
        'length_mode': 'uncapped',
        'card_scope': 'due',
        'started_at': DateTime.utc(2026).toIso8601String(),
        'is_synced': 1,
      });
      await database.db.insert('offline_session_cards', {
        'id': 'sc-active',
        'session_id': 's1',
        'card_id': 'active',
        'position': 0,
        'is_synced': 1,
      });
      await database.db.insert('offline_study_sessions', {
        'id': 's2',
        'deck_id': 'd1',
        'status': 'completed',
        'study_mode': 'flip',
        'length_mode': 'uncapped',
        'card_scope': 'due',
        'started_at': DateTime.utc(2026).toIso8601String(),
        'completed_at': DateTime.utc(2026, 1, 2).toIso8601String(),
        'is_synced': 1,
      });
      await database.db.insert('offline_session_cards', {
        'id': 'sc-pending',
        'session_id': 's2',
        'card_id': 'pending',
        'position': 0,
        'is_synced': 0,
      });

      await store.removeDeck('d1');

      expect(await store.isCardSetComplete('d1'), isFalse);
      expect(
        (await store.cards('d1')).map((c) => c.id),
        unorderedEquals(['active', 'pending']),
      );
      expect(await database.db.query('offline_study_sessions'), hasLength(2));
      expect(await database.db.query('offline_session_cards'), hasLength(2));
      expect(await database.db.query('offline_decks'), hasLength(1));
    },
  );
}
