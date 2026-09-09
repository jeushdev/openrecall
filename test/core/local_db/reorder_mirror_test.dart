import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';

import '../../support/local_db_harness.dart';

Course _course(String id, String name) => Course(
  id: id,
  userId: 'u1',
  name: name,
  accentColor: 'green',
  isDefault: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

/// A drag-reorder made offline (milestone E3): each id's list index becomes its
/// `position`, the rows are marked `is_synced = 0` for the reconnect push, and
/// the cached reads come back in the new order.
void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalDeckStore decks;
  late LocalCourseStore courses;

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    decks = LocalDeckStore(db.db);
    courses = LocalCourseStore(db.db);
  });

  test(
    'reorderDecks stamps position, marks rows unsynced, and reorders reads',
    () async {
      await decks.pinDeck(deckId: 'a', name: 'A');
      await decks.pinDeck(deckId: 'b', name: 'B');
      await decks.pinDeck(deckId: 'c', name: 'C');

      await decks.reorderDecks(['c', 'a', 'b']);

      final summaries = await decks.cachedDeckSummaries();
      expect(summaries.map((d) => d.id), ['c', 'a', 'b']);
      expect(summaries.map((d) => d.position), [0, 1, 2]);

      final dirty = await decks.unsyncedDecks();
      expect(dirty.map((d) => d.id).toSet(), {'a', 'b', 'c'});
      expect(
        {for (final d in dirty) d.id: d.position},
        {'c': 0, 'a': 1, 'b': 2},
      );
    },
  );

  test('reorderCourses does the same for offline_courses', () async {
    await courses.refreshCourses([
      _course('a', 'A'),
      _course('b', 'B'),
      _course('c', 'C'),
    ]);

    await courses.reorderCourses(['c', 'a', 'b']);

    final cached = await courses.cachedCourses();
    expect(cached.map((c) => c.id), ['c', 'a', 'b']);
    expect(cached.map((c) => c.position), [0, 1, 2]);

    final dirty = await courses.unsyncedCourses();
    expect({for (final c in dirty) c.id: c.position}, {'c': 0, 'a': 1, 'b': 2});
  });

  test('reorderDecks skips ids not in the mirror', () async {
    await decks.pinDeck(deckId: 'a', name: 'A');
    await decks.reorderDecks(['ghost', 'a']);
    final summaries = await decks.cachedDeckSummaries();
    expect(summaries.single.id, 'a');
    expect(summaries.single.position, 1);
  });
}
