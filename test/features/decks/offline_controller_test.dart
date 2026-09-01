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

FlashCard _card(String id, String deckId, {String front = 'Q', String back = 'A'}) =>
    FlashCard(
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
  Future<List<FlashCard>> fetchCardsPage(String deckId,
      {required int offset, required int limit}) async {
    pageOffsets.add(offset);
    return [
      for (var i = offset; i < offset + limit && i < total; i++)
        _card('c$i', deckId, front: 'Q$i', back: 'A$i'),
    ];
  }
}

void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase db;
  setUp(() async => db = await openTestDatabase());
  tearDown(() async => db.close());

  ProviderContainer containerWith(OfflineDownloadSource source) {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      offlineDownloadSourceProvider.overrideWithValue(source),
    ]);
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
    await store.mirrorCards('d1', [_card('c0', 'd1')]);
    expect(await store.pinnedDeckIds(), isEmpty);

    final c = containerWith(_PagedSource(2));
    await c
        .read(offlineControllerProvider.notifier)
        .updateOfflineCopy('d1');

    expect((await store.cards('d1')).length, 2);
    expect(await store.pinnedDeckIds(), isEmpty,
        reason: 'updating a copy never changes the pin');
  });
}
