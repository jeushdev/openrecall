import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';

import '../../support/local_db_harness.dart';

FlashCard _card(
  String id, {
  String deckId = 'd1',
  String front = 'Q',
  DateTime? createdAt,
}) => FlashCard(
  id: id,
  deckId: deckId,
  front: front,
  back: 'A',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: createdAt ?? DateTime.utc(2026),
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
    'active session rejects removal without changing package state',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('active')],
        pin: true,
      );
      await _insertSession(database, id: 's1', status: 'active');

      await expectLater(
        store.removeDeck('d1'),
        throwsA(isA<OfflinePackageActiveSessionException>()),
      );

      expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
      expect((await store.cards('d1')).single.id, 'active');
      expect(await store.hasActiveSession('d1'), isTrue);
    },
  );

  test('queue-only pending work retains a clean nonmember card', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Deck',
      cards: [_card('pending'), _card('clean')],
      pin: true,
    );
    await _insertSession(database, id: 's1', status: 'completed');
    await database.db.insert('offline_session_cards', {
      'id': 'queue',
      'session_id': 's1',
      'card_id': 'pending',
      'position': 0,
      'is_synced': 0,
    });

    expect(await store.deckHasUnsyncedWork('d1'), isTrue);
    await store.removeDeck('d1');

    expect(await store.cardById('pending'), isNotNull);
    expect(await store.cardById('clean'), isNull);
    expect(await store.cards('d1'), isEmpty);
    expect(await database.db.query('offline_study_sessions'), hasLength(1));
    expect(await database.db.query('offline_session_cards'), hasLength(1));
  });

  test(
    'tombstone-only pending work is detected and survives removal',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('deleted')],
        pin: true,
      );
      await store.deleteCard('deleted');
      expect(await store.deckHasUnsyncedWork('d1'), isTrue);

      await store.removeDeck('d1');

      expect((await store.cardDeletions()).single.entityId, 'deleted');
      expect(await store.deckHasUnsyncedWork('d1'), isTrue);
    },
  );

  test('deck tombstone alone is pending work', () async {
    await store.createDeck(id: 'd1', name: 'Local');
    await store.deleteDeck('d1');

    expect(await store.deckHasUnsyncedWork('d1'), isTrue);
    expect((await store.deckDeletions()).single.entityId, 'd1');
  });

  test('confirmed remote-missing state is durable and typed', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Deck',
      cards: [_card('card')],
      pin: true,
    );
    await store.setRemoteMissing('d1', missing: true);

    final status = await store.packageStatus('d1');
    expect(status.remoteMissing, isTrue);
    expect(status.isExplicitlyAvailable, isTrue);
  });

  test(
    'replacement retains protected clean card but excludes it from reads',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('old'), _card('current')],
      );
      await _insertSession(
        database,
        id: 's1',
        status: 'completed',
        synced: false,
      );
      await database.db.insert('offline_session_cards', {
        'id': 'queue',
        'session_id': 's1',
        'card_id': 'old',
        'position': 0,
        'is_synced': 1,
      });

      await store.commitDeckPackage(deckId: 'd1', cards: [_card('current')]);

      expect(await store.cardById('old'), isNotNull);
      expect((await store.cards('d1')).map((card) => card.id), ['current']);
      expect((await store.cachedDeckSummaries()).single.totalCards, 1);
    },
  );

  test(
    'dirty cards remain as the local overlay in reads and aggregates',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('dirty'), _card('current')],
      );
      await store.updateCardContent(
        id: 'dirty',
        front: 'Local',
        back: 'A',
        keywords: const [],
        isConcept: false,
      );

      await store.commitDeckPackage(deckId: 'd1', cards: [_card('current')]);

      expect((await store.cards('d1')).map((card) => card.id), [
        'current',
        'dirty',
      ]);
      expect((await store.cardById('dirty'))!.front, 'Local');
      expect((await store.cachedDeckSummaries()).single.totalCards, 2);
    },
  );

  test(
    'removal is idempotent, suppressed, and preserves shared course metadata',
    () async {
      await database.db.insert('offline_courses', {
        'id': 'course',
        'name': 'Science',
        'accent_color': '#000000',
      });
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'One',
        courseId: 'course',
        cards: [_card('one')],
        pin: true,
      );
      await store.commitDeckPackage(
        deckId: 'd2',
        deckName: 'Two',
        courseId: 'course',
        cards: [_card('two', deckId: 'd2')],
        pin: true,
      );

      await store.removeDeck('d1');
      await store.removeDeck('d1');

      final status = await store.packageStatus('d1');
      expect(status.availability, OfflinePackageAvailability.suppressed);
      expect(status.cardsComplete, isFalse);
      expect(await database.db.query('offline_courses'), hasLength(1));
      expect((await store.packageStatus('d2')).isExplicitlyAvailable, isTrue);

      // Incidental caching cannot undo removal; explicit download can.
      await store.commitDeckPackage(deckId: 'd1', cards: [_card('incidental')]);
      expect((await store.packageStatus('d1')).cardsComplete, isFalse);
      await store.commitDeckPackage(
        deckId: 'd1',
        cards: [_card('explicit')],
        pin: true,
      );
      expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
    },
  );

  test('stable ordering uses id to break created-at ties', () async {
    final tied = DateTime.utc(2026, 1, 1);
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Deck',
      cards: [
        _card('z', createdAt: tied),
        _card('a', createdAt: tied),
        _card('m', createdAt: tied),
      ],
    );
    expect((await store.cards('d1')).map((card) => card.id), ['a', 'm', 'z']);
  });

  test(
    'authored card does not convert incomplete coverage into complete',
    () async {
      await store.pinDeck(deckId: 'd1', name: 'Partial');
      await store.insertCards([_card('local')]);

      final status = await store.packageStatus('d1');
      expect(status.availability, OfflinePackageAvailability.incomplete);
      expect(status.cardsComplete, isFalse);
      expect((await store.cards('d1')).single.id, 'local');
      final row = (await database.db.query('offline_cards')).single;
      expect(row['in_current_package'], 0);
    },
  );

  test('stale operation generation cannot commit a package', () async {
    const stale = OfflinePackageOperation(
      deckId: 'd1',
      generation: 1,
      kind: OfflinePackageOperationKind.download,
    );
    await expectLater(
      store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('late')],
        pin: true,
        operation: stale,
        isOperationCurrent: (_) => false,
      ),
      throwsA(isA<OfflinePackageOperationSuperseded>()),
    );
    expect(
      (await store.packageStatus('d1')).availability,
      OfflinePackageAvailability.unavailable,
    );
  });

  test('general-list pruning retains pinned parents without confirming remote missing', () async {
    await database.db.insert('offline_courses', {
      'id': 'protected-course',
      'name': 'Protected',
      'accent_color': '#000000',
      'is_synced': 1,
    });
    await database.db.insert('offline_courses', {
      'id': 'discardable-course',
      'name': 'Discardable',
      'accent_color': '#000000',
      'is_synced': 1,
    });
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Pinned',
      courseId: 'protected-course',
      cards: [_card('protected')],
      pin: true,
    );
    await store.commitDeckPackage(
      deckId: 'd2',
      deckName: 'Opportunistic',
      courseId: 'discardable-course',
      cards: [_card('discardable', deckId: 'd2')],
    );

    await store.refreshDeckMeta(const []);
    await LocalCourseStore(database.db).refreshCourses(const []);

    expect((await store.packageStatus('d1')).remoteMissing, isFalse);
    expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
    expect(await store.cardById('protected'), isNotNull);
    expect(await store.cardById('discardable'), isNull);
    expect(
      (await database.db.query('offline_courses')).map((row) => row['id']),
      ['protected-course'],
    );
  });

  test(
    'retained-card cleanup waits for every session reference acknowledgment',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Deck',
        cards: [_card('retained'), _card('current')],
        pin: true,
      );
      await _insertSession(
        database,
        id: 's1',
        status: 'completed',
        synced: false,
      );
      await database.db.insert('offline_session_cards', {
        'id': 'queue',
        'session_id': 's1',
        'card_id': 'retained',
        'position': 0,
        'is_synced': 0,
      });
      await store.commitDeckPackage(deckId: 'd1', cards: [_card('current')]);

      expect(await store.cleanupRetainedCards(deckIds: {'d1'}), isEmpty);
      expect(await store.cardById('retained'), isNotNull);

      await database.db.update(
        'offline_study_sessions',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: ['s1'],
      );
      expect(await store.cleanupRetainedCards(deckIds: {'d1'}), isEmpty);
      expect(await store.cardById('retained'), isNotNull);

      await database.db.update(
        'offline_session_cards',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: ['queue'],
      );
      expect(await store.cleanupRetainedCards(deckIds: {'d1'}), {'d1'});
      expect(await store.cardById('retained'), isNull);
      expect(await store.cardById('current'), isNotNull);
      expect(await database.db.query('offline_study_sessions'), hasLength(1));
      expect(await database.db.query('offline_session_cards'), hasLength(1));
    },
  );
}

Future<void> _insertSession(
  AppDatabase database, {
  required String id,
  required String status,
  bool synced = true,
}) {
  return database.db.insert('offline_study_sessions', {
    'id': id,
    'deck_id': 'd1',
    'status': status,
    'study_mode': 'flip',
    'length_mode': 'uncapped',
    'card_scope': 'due',
    'started_at': DateTime.utc(2026).toIso8601String(),
    if (status == 'completed')
      'completed_at': DateTime.utc(2026, 1, 2).toIso8601String(),
    'is_synced': synced ? 1 : 0,
  });
}
