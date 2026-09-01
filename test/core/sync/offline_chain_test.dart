import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
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

/// The local side of a fully-offline authoring session, against the real
/// SQLite mirror (milestone E3 Task 8). It proves the mirror produces a
/// correctly-linked, FK-safe set of unsynced rows; the actual Supabase upsert
/// order is `SyncService`'s explicit course → deck → card-content sequence
/// (already shipped) plus the manual airplane-mode walkthrough.
void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalCourseStore courses;
  late LocalDeckStore decks;

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    courses = LocalCourseStore(db.db);
    decks = LocalDeckStore(db.db);
  });

  test('create course → deck → card yields parent-first, correctly-linked '
      'unsynced rows', () async {
    final course = await courses.createCourse(
        id: 'c1', userId: 'u1', name: 'Bio', accentColor: 'green');
    await decks.createDeck(id: 'd1', name: 'Chapter 1', courseId: course.id);
    await decks.insertCards([_card('k1', 'd1')]);

    final dirtyCourses = await courses.unsyncedCourses();
    final dirtyDecks = await decks.unsyncedDecks();
    final dirtyCards = await decks.contentDirtyCards();

    expect(dirtyCourses.single.id, 'c1');
    expect(dirtyCourses.single.createdLocally, isTrue);
    expect(dirtyDecks.single.id, 'd1');
    expect(dirtyDecks.single.createdLocally, isTrue);
    expect(dirtyDecks.single.courseId, 'c1',
        reason: 'client UUID — the child points at the real parent id, no remap');
    expect(dirtyCards.single.deckId, 'd1');
  });

  test('offline card add then deck delete: the deck tombstone subsumes the card',
      () async {
    await decks.createDeck(id: 'd1', name: 'Chapter 1', courseId: 'c1');
    await decks.insertCards([_card('k1', 'd1'), _card('k2', 'd1')]);

    await decks.deleteDeck('d1');

    final deckTombstones = await decks.deckDeletions();
    expect(deckTombstones.single.entityId, 'd1');
    expect(deckTombstones.single.createdLocally, isTrue);
    expect(await decks.cardDeletions(), isEmpty,
        reason: 'the deck-level delete cascades server-side');
    expect(await decks.contentDirtyCards(), isEmpty);
  });

  test('two offline decks: both are unsynced and created-locally', () async {
    await decks.createDeck(id: 'd1', name: 'One', courseId: 'c1');
    await decks.createDeck(id: 'd2', name: 'Two', courseId: 'c1');

    final dirty = await decks.unsyncedDecks();
    expect(dirty.map((d) => d.id).toSet(), {'d1', 'd2'});
    expect(dirty.every((d) => d.createdLocally), isTrue);
  });
}
