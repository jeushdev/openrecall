import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';

import '../../support/local_db_harness.dart';

FlashCard _card(String id, String deckId) => FlashCard(
      id: id,
      deckId: deckId,
      front: 'Q$id',
      back: 'A$id',
      keywords: const [],
      isConcept: false,
      masteryLevel: 0,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// Regression: `insertCards` used to write `base_updated_at = NULL` into a
/// `NOT NULL` column, so offline card authoring threw `SqliteException(1299)`
/// on a real device (milestone E2's real-DB harness surfaced it; milestone E3
/// fixes it with the `created_locally` flag).
void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalDeckStore store;

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    store = LocalDeckStore(db.db);
  });

  test('insertCards persists an offline-authored card as content-dirty', () async {
    await store.insertCards([_card('k1', 'd1'), _card('k2', 'd1')]);

    final dirty = await store.contentDirtyCards();
    expect(dirty.map((c) => c.id).toSet(), {'k1', 'k2'});
    expect(await store.cards('d1'), hasLength(2));
  });

  test('deleting an offline-authored card writes a created_locally tombstone',
      () async {
    await store.insertCards([_card('k1', 'd1')]);
    await store.deleteCard('k1');

    final tombstones = await store.cardDeletions();
    expect(tombstones.single.entityId, 'k1');
    expect(tombstones.single.createdLocally, isTrue,
        reason: 'never reached Supabase — the remote DELETE must be skipped');
    expect(await store.cards('d1'), isEmpty);
  });

  test('a card synced then deleted is not marked created_locally', () async {
    await store.insertCards([_card('k1', 'd1')]);
    await store.markCardContentSynced('k1', DateTime.utc(2026, 2));
    await store.deleteCard('k1');

    expect((await store.cardDeletions()).single.createdLocally, isFalse);
  });
}
