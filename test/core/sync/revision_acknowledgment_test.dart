import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';

import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'course and deck acknowledgments match the sent local revision',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = LocalCourseStore(database.db);
      final decks = LocalDeckStore(database.db);
      await courses.createCourse(
        id: 'course-1',
        userId: 'user-1',
        name: 'Biology',
        accentColor: 'green',
      );
      await decks.createDeck(id: 'deck-1', name: 'Cells', courseId: 'course-1');
      final sentCourse = (await courses.unsyncedCourses()).single;
      final sentDeck = (await decks.unsyncedDecks()).single;

      await courses.updateCourse(id: 'course-1', name: 'Advanced Biology');
      await decks.updateDeck(id: 'deck-1', name: 'Cell Biology');
      await courses.markCourseSynced(
        sentCourse.id,
        DateTime.utc(2026, 2),
        sentRevision: sentCourse,
      );
      await decks.markDeckSynced(
        sentDeck.id,
        DateTime.utc(2026, 2),
        sentRevision: sentDeck,
      );

      expect((await courses.unsyncedCourses()).single.name, 'Advanced Biology');
      expect((await decks.unsyncedDecks()).single.name, 'Cell Biology');
    },
  );

  test('card-content acknowledgment preserves a newer local edit', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final decks = LocalDeckStore(database.db);
    await decks.insertCards([
      FlashCard(
        id: 'card-1',
        deckId: 'deck-1',
        front: 'Question',
        back: 'Answer',
        keywords: const [],
        isConcept: false,
        masteryLevel: 0,
        failCount: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    final sent = (await decks.contentDirtyCards()).single;

    await decks.updateCardContent(
      id: 'card-1',
      front: 'New question',
      back: 'New answer',
      keywords: const ['new'],
      isConcept: true,
    );
    await decks.markCardContentSynced(
      sent.id,
      DateTime.utc(2026, 2),
      sentRevision: sent,
    );

    final stillDirty = (await decks.contentDirtyCards()).single;
    expect(stillDirty.front, 'New question');
    expect(stillDirty.back, 'New answer');
    expect(stillDirty.keywords, ['new']);
    expect(stillDirty.isConcept, isTrue);
  });
}
