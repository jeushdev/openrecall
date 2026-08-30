import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';

void main() {
  // The project has no sqflite_common_ffi dev dependency and no real-DB store
  // tests (see local_stats_store_test.dart). The contract pinned here is the
  // no-database degradation every local store shares, so a cache-first
  // repository wrapping this store behaves exactly like the plain Supabase one.
  // The real offline-authoring behaviour is covered by the manual airplane-mode
  // walkthrough in the spec-v4 verification checklist.
  group('LocalDeckStore with no database', () {
    final store = LocalDeckStore(null);

    test('is a no-op', () {
      expect(store.isNoop, isTrue);
    });

    test('membership reads return empty', () async {
      expect(await store.downloadedDeckIds(), isEmpty);
      expect(await store.pinnedDeckIds(), isEmpty);
      expect(await store.isDownloaded('d1'), isFalse);
    });

    test('refreshDeckMeta / mirrorCards do not throw', () async {
      await store.refreshDeckMeta(const []);
      await store.mirrorCards('d1', const []);
    });

    test('offline content writes do not throw', () async {
      await store.createDeck(id: 'd1', name: 'Bio', courseId: 'c1');
      await store.updateDeck(id: 'd1', name: 'Biology');
      await store.deleteDeck('d1');
      await store.insertCards([
        FlashCard(
          id: 'card1',
          deckId: 'd1',
          front: 'Q',
          back: 'A',
          keywords: const [],
          isConcept: false,
          masteryLevel: 0,
          failCount: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ]);
      await store.updateCardContent(
        id: 'card1',
        front: 'Q2',
        back: 'A2',
        keywords: const ['k'],
        isConcept: true,
      );
      await store.deleteCard('card1');
    });

    test('sync-support reads return empty', () async {
      expect(await store.unsyncedCards(), isEmpty);
      expect(await store.contentDirtyCards(), isEmpty);
      expect(await store.unsyncedDecks(), isEmpty);
      expect(await store.deckDeletions(), isEmpty);
      expect(await store.cardDeletions(), isEmpty);
    });

    test('mark-synced / clear-deletion helpers do not throw', () async {
      final ts = DateTime.utc(2026);
      await store.markCardSynced('card1', ts);
      await store.markCardContentSynced('card1', ts);
      await store.markDeckSynced('d1', ts);
      await store.clearDeckDeletion('d1');
      await store.clearCardDeletion('card1');
    });
  });
}
