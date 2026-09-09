import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/offline_deck_service.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/deck_repository.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';

import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase database;
  late LocalDeckStore store;
  setUp(() async {
    database = await openTestDatabase();
    store = LocalDeckStore(database.db);
  });
  tearDown(() => database.close());

  OfflineDeckService service(
    _Source source, {
    LocalDeckStore? local,
    OfflinePackageOperationRegistry? operations,
    Duration requestTimeout = const Duration(seconds: 1),
  }) => OfflineDeckService(
    local: local ?? store,
    source: source,
    operations: operations ?? OfflinePackageOperationRegistry(),
    isOnline: () async => true,
    requestTimeout: requestTimeout,
    overallTimeout: const Duration(seconds: 3),
  );

  test(
    'installs a self-contained zero-card package from an empty mirror',
    () async {
      final source = _Source(0);

      await service(source).download('d1', pin: true);

      final deck = (await database.db.query('offline_decks')).single;
      final course = (await database.db.query('offline_courses')).single;
      expect(deck['name'], 'Remote deck');
      expect(deck['course_id'], 'course-1');
      expect(course['name'], 'Remote course');
      expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
      expect(await store.cards('d1'), isEmpty);
    },
  );

  test('fetches representative page boundaries completely', () async {
    for (final total in [1, 100, 101, 350]) {
      final source = _Source(total);
      await service(source).download('d$total', pin: true);
      expect((await store.cards('d$total')).length, total);
      expect(source.pageOffsets, [
        for (var offset = 0; offset < total; offset += 100) offset,
      ]);
    }
  });

  test(
    'preserves a dirty local course reassignment with its metadata',
    () async {
      await database.db.insert('offline_courses', {
        'id': 'course-2',
        'user_id': 'user-1',
        'name': 'Local course',
        'accent_color': 'blue',
        'is_default': 0,
        'created_at': DateTime.utc(2026).toIso8601String(),
        'updated_at': DateTime.utc(2026).toIso8601String(),
        'base_updated_at': DateTime.utc(2026).toIso8601String(),
        'is_synced': 1,
      });
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Old deck',
        courseId: 'course-2',
        cards: [_card('old', 'd1')],
        pin: true,
      );
      await store.updateDeck(
        id: 'd1',
        name: 'Locally renamed',
        courseId: 'course-2',
      );

      await service(_Source(1)).download('d1', pin: true);

      final deck = (await database.db.query('offline_decks')).single;
      expect(deck['name'], 'Locally renamed');
      expect(deck['course_id'], 'course-2');
      expect(
        (await database.db.query(
          'offline_courses',
          where: 'id = ?',
          whereArgs: ['course-2'],
        )).single['name'],
        'Local course',
      );
      expect((await store.cards('d1')).single.id, 'c0');
    },
  );

  test('rejects short, duplicate, and wrong-deck pages', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Old',
      cards: [_card('old', 'd1')],
      pin: true,
    );

    for (final corruption in _Corruption.values) {
      final source = _Source(2)..corruption = corruption;
      await expectLater(
        service(source).download('d1', pin: true),
        throwsA(
          isA<OfflineDeckServiceException>().having(
            (e) => e.code,
            'code',
            OfflineDeckServiceErrorCode.invalidPackage,
          ),
        ),
      );
      expect((await store.cards('d1')).single.id, 'old');
      expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
    }
  });

  test('request timeout preserves the prior valid package', () async {
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Old',
      cards: [_card('old', 'd1')],
      pin: true,
    );
    final source = _Source(1)..stalledCount = Completer<int>();

    await expectLater(
      service(
        source,
        requestTimeout: const Duration(milliseconds: 20),
      ).download('d1', pin: true),
      throwsA(
        isA<OfflineDeckServiceException>().having(
          (e) => e.code,
          'code',
          OfflineDeckServiceErrorCode.timedOut,
        ),
      ),
    );

    expect((await store.cards('d1')).single.id, 'old');
    expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
  });

  test(
    'a superseded operation cannot commit after its page completes',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Old',
        cards: [_card('old', 'd1')],
        pin: true,
      );
      final operations = OfflinePackageOperationRegistry();
      final source = _Source(1)..pageGate = Completer<void>();
      final download = service(
        source,
        operations: operations,
      ).download('d1', pin: true);
      await source.pageStarted.future;

      operations.cancel('d1');
      source.pageGate!.complete();

      await expectLater(
        download,
        throwsA(
          isA<OfflineDeckServiceException>().having(
            (e) => e.code,
            'code',
            OfflineDeckServiceErrorCode.superseded,
          ),
        ),
      );
      expect((await store.cards('d1')).single.id, 'old');
    },
  );

  test('an account switch cannot commit into the new account', () async {
    await database.scopeAccount('account-a');
    final generation = database.scopeGeneration;
    final scopedStore = LocalDeckStore(
      database.db,
      isCurrent: () =>
          database.scopeReady && database.scopeGeneration == generation,
    );
    final source = _Source(1)..pageGate = Completer<void>();
    final download = service(
      source,
      local: scopedStore,
    ).download('d1', pin: true);
    await source.pageStarted.future;

    await database.scopeAccount('account-b');
    source.pageGate!.complete();

    await expectLater(
      download,
      throwsA(
        isA<OfflineDeckServiceException>().having(
          (e) => e.code,
          'code',
          OfflineDeckServiceErrorCode.superseded,
        ),
      ),
    );
    expect(await database.db.query('offline_decks'), isEmpty);
    expect(await database.db.query('offline_cards'), isEmpty);
  });

  test(
    'an insert failure rolls back metadata, cards, and package flags',
    () async {
      await store.commitDeckPackage(
        deckId: 'd1',
        deckName: 'Old',
        cards: [_card('old', 'd1')],
        pin: true,
      );
      await database.db.execute('''
      CREATE TRIGGER fail_new_card BEFORE INSERT ON offline_cards
      WHEN NEW.id = 'c0'
      BEGIN SELECT RAISE(ABORT, 'injected insert failure'); END
    ''');

      await expectLater(
        service(_Source(1)).download('d1', pin: true),
        throwsA(
          isA<OfflineDeckServiceException>().having(
            (e) => e.code,
            'code',
            OfflineDeckServiceErrorCode.storageFailure,
          ),
        ),
      );

      expect((await store.cards('d1')).single.id, 'old');
      final deck = (await database.db.query('offline_decks')).single;
      expect(deck['name'], 'Old');
      expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
    },
  );

  test('retry succeeds cleanly after a request failure', () async {
    final source = _Source(101)..failNextCount = true;
    final downloader = service(source);

    await expectLater(
      downloader.download('d1', pin: true),
      throwsA(
        isA<OfflineDeckServiceException>().having(
          (e) => e.code,
          'code',
          OfflineDeckServiceErrorCode.requestFailed,
        ),
      ),
    );
    expect((await store.packageStatus('d1')).cardsComplete, isFalse);

    await downloader.download('d1', pin: true);
    expect((await store.cards('d1')).length, 101);
    expect((await store.packageStatus('d1')).isExplicitlyAvailable, isTrue);
  });

  test('duplicate taps share one in-flight fetch', () async {
    final source = _Source(1)..pageGate = Completer<void>();
    final downloader = service(source);
    final first = downloader.download('d1', pin: true);
    final second = downloader.download('d1', pin: true);
    expect(identical(first, second), isTrue);
    await source.pageStarted.future;
    source.pageGate!.complete();
    await Future.wait([first, second]);
    expect(source.pageOffsets, [0]);
  });
}

enum _Corruption { short, duplicate, wrongDeck }

class _Source implements OfflineDownloadSource {
  _Source(this.total);

  final int total;
  final List<int> pageOffsets = [];
  final Completer<void> pageStarted = Completer<void>();
  Completer<void>? pageGate;
  Completer<int>? stalledCount;
  bool failNextCount = false;
  _Corruption? corruption;

  @override
  Future<Deck?> fetchDeck(String deckId) async => Deck(
    id: deckId,
    name: 'Remote deck',
    courseId: 'course-1',
    lastStudiedAt: null,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    position: 3,
  );

  @override
  Future<Course?> fetchCourse(String courseId) async => Course(
    id: courseId,
    userId: 'user-1',
    name: 'Remote course',
    accentColor: 'green',
    isDefault: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    position: 2,
  );

  @override
  Future<int> countCards(String deckId) async {
    if (failNextCount) {
      failNextCount = false;
      throw StateError('network failed');
    }
    if (stalledCount != null) return stalledCount!.future;
    return total;
  }

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async {
    pageOffsets.add(offset);
    if (!pageStarted.isCompleted) pageStarted.complete();
    if (pageGate != null) await pageGate!.future;
    final page = [
      for (var i = offset; i < offset + limit && i < total; i++)
        _card('c$i', deckId),
    ];
    return switch (corruption) {
      _Corruption.short => page.take(page.length - 1).toList(),
      _Corruption.duplicate => [_card('same', deckId), _card('same', deckId)],
      _Corruption.wrongDeck => [
        _card('wrong', 'another-deck'),
        ...page.skip(1),
      ],
      null => page,
    };
  }
}

FlashCard _card(String id, String deckId) => FlashCard(
  id: id,
  deckId: deckId,
  front: 'Question $id',
  back: 'Answer $id',
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
