import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck_repository.dart';
import 'package:open_recall/features/decks/domain/offline_download.dart';

import '../../support/local_db_harness.dart';

FlashCard _card(
  String id,
  String deckId, {
  String front = 'Q',
  String back = 'A',
}) => FlashCard(
  id: id,
  deckId: deckId,
  front: front,
  back: back,
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// A paged source that hands back [total] synthetic cards in pages, recording
/// every page request so the test can assert the download chunked rather than
/// pulling everything at once.
class _PagedSource implements OfflineDownloadSource {
  _PagedSource(this.total);
  final int total;
  final List<int> pageOffsets = [];

  @override
  Future<int> countCards(String deckId) async => total;

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async {
    pageOffsets.add(offset);
    return [
      for (var i = offset; i < offset + limit && i < total; i++)
        _card('c$i', deckId, front: 'Q$i', back: 'A$i'),
    ];
  }
}

class _PartialSource extends _PagedSource {
  _PartialSource(super.total);

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async {
    if (offset >= 100) return const [];
    return super.fetchCardsPage(deckId, offset: offset, limit: limit);
  }
}

class _DuplicateSource extends _PagedSource {
  _DuplicateSource() : super(2);

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async => [_card('same', deckId), _card('same', deckId)];
}

void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase db;
  setUp(() async => db = await openTestDatabase());
  tearDown(() async => db.close());

  ProviderContainer containerWith(OfflineDownloadSource source) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        offlineDownloadSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('download reports monotonic progress and completes', () async {
    final source = _PagedSource(250); // 3 pages at kDownloadPageSize = 100
    final c = containerWith(source);

    final seen = <DownloadProgress>[];
    final sub = c.listen(downloadProgressProvider, (_, next) {
      if (next != null) seen.add(next);
    });
    addTearDown(sub.close);

    await c.read(offlineControllerProvider.notifier).download('d1', 'Biology');

    for (var i = 1; i < seen.length; i++) {
      expect(seen[i].done, greaterThanOrEqualTo(seen[i - 1].done));
    }
    expect(seen.last.done, 250);
    expect(seen.last.total, 250);
    expect(source.pageOffsets, [0, 100, 200]);
    expect(c.read(downloadProgressProvider), isNull);

    final store = LocalDeckStore(db.db);
    expect((await store.cards('d1')).length, 250);
    expect(await store.pinnedDeckIds(), contains('d1'));
  });

  test('pinned provider excludes an incomplete metadata-only row', () async {
    final store = LocalDeckStore(db.db);
    await store.pinDeck(deckId: 'd1', name: 'Biology');
    final c = containerWith(_PagedSource(0));

    expect(await c.read(offlineDeckIdsProvider.future), isEmpty);

    await c.read(offlineControllerProvider.notifier).download('d1', 'Biology');
    expect(await c.read(offlineDeckIdsProvider.future), contains('d1'));
  });

  test('download preserves an unsynced local card edit', () async {
    final store = LocalDeckStore(db.db);
    await store.pinDeck(deckId: 'd1', name: 'Biology');
    // A card mirrored from the server, then edited offline (is_synced = 0,
    // content_dirty = 1).
    await store.mirrorCards('d1', [_card('c0', 'd1', front: 'server')]);
    await store.updateCardContent(
      id: 'c0',
      front: 'edited',
      back: 'locally',
      keywords: const [],
      isConcept: false,
    );

    final c = containerWith(_PagedSource(3)); // server also returns c0..c2
    await c.read(offlineControllerProvider.notifier).download('d1', 'Biology');

    final c0 = await store.cardById('c0');
    expect(c0!.front, 'edited', reason: 'the unsynced local edit survives');
    expect((await store.contentDirtyCards()).map((c) => c.id), contains('c0'));
  });

  test('updateOfflineCopy refreshes the mirror without pinning', () async {
    final store = LocalDeckStore(db.db);
    // A deck auto-cached by opening it online (row exists, not pinned).
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Biology',
      cards: [_card('c0', 'd1')],
    );
    expect(await store.pinnedDeckIds(), isEmpty);

    final c = containerWith(_PagedSource(2));
    await c.read(offlineControllerProvider.notifier).updateOfflineCopy('d1');

    expect((await store.cards('d1')).length, 2);
    expect(
      await store.pinnedDeckIds(),
      isEmpty,
      reason: 'updating a copy never changes the pin',
    );
  });

  test(
    'a partial download is rejected without becoming ready or pinned',
    () async {
      final c = containerWith(_PartialSource(150));

      await c
          .read(offlineControllerProvider.notifier)
          .download('d1', 'Biology');

      final store = LocalDeckStore(db.db);
      expect(c.read(offlineControllerProvider), isA<AsyncError<void>>());
      expect(await store.isCardSetComplete('d1'), isFalse);
      expect(await store.pinnedDeckIds(), isEmpty);
    },
  );

  test('duplicate card ids are rejected before the package commit', () async {
    final c = containerWith(_DuplicateSource());

    await c.read(offlineControllerProvider.notifier).download('d1', 'Biology');

    expect(c.read(offlineControllerProvider), isA<AsyncError<void>>());
    expect(await LocalDeckStore(db.db).isCardSetComplete('d1'), isFalse);
  });

  test('a verified zero-card deck is a complete pinned package', () async {
    final c = containerWith(_PagedSource(0));

    await c.read(offlineControllerProvider.notifier).download('d1', 'Empty');

    final store = LocalDeckStore(db.db);
    expect(await store.isCardSetComplete('d1'), isTrue);
    expect(await store.cards('d1'), isEmpty);
    expect(await store.pinnedDeckIds(), contains('d1'));
  });

  test('failed update keeps the prior complete package usable', () async {
    final store = LocalDeckStore(db.db);
    await store.commitDeckPackage(
      deckId: 'd1',
      deckName: 'Biology',
      cards: [_card('old', 'd1', front: 'Old')],
      pin: true,
    );
    final c = containerWith(_PartialSource(150));

    await c.read(offlineControllerProvider.notifier).updateOfflineCopy('d1');

    expect(c.read(offlineControllerProvider), isA<AsyncError<void>>());
    expect(await store.isCardSetComplete('d1'), isTrue);
    expect((await store.cards('d1')).single.id, 'old');
    expect(await store.pinnedDeckIds(), contains('d1'));
  });
}
