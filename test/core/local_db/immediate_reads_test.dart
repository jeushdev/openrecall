import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  FlashCard card(String id, {String front = 'remote'}) => FlashCard(
    id: id,
    deckId: 'deck',
    front: front,
    back: 'answer',
    keywords: const [],
    isConcept: false,
    masteryLevel: 0,
    failCount: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  const deck = DeckSummary(
    id: 'deck',
    name: 'Biology',
    lastStudiedAt: null,
    totalCards: 4,
    dueCards: 4,
    masteryPercent: 0,
  );

  test(
    'metadata-only and legacy-unverified card sets are unavailable',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final local = LocalDeckStore(database.db);
      await local.refreshDeckMeta(const [deck]);
      await database.db.insert('offline_cards', {
        'id': 'legacy-card',
        'deck_id': 'deck',
        'front': 'legacy',
        'back': 'answer',
        'mastery_level': 0,
        'fail_count': 0,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'base_updated_at': '2026-01-01T00:00:00.000Z',
      });
      expect(await local.isCardSetComplete('deck'), isFalse);
      expect(
        (await local.cachedDeckSummaries()).single.totalCards,
        4,
        reason: 'an unverified partial row is not treated as the full set',
      );

      final repository = CacheFirstDeckRepository(
        FakeDeckRepository()..alwaysThrow = StateError('offline'),
        local,
        LocalCourseStore(database.db),
      );
      await expectLater(
        repository.fetchCards('deck'),
        throwsA(isA<DeckUnavailableOfflineException>()),
      );
    },
  );

  test('a verified empty deck is a complete cache entry', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final local = LocalDeckStore(database.db);
    await local.refreshDeckMeta(const [deck]);

    await local.mirrorCards('deck', const []);

    expect(await local.isCardSetComplete('deck'), isTrue);
    expect(await local.completeCardDeckIds(), {'deck'});
    expect(await local.cards('deck'), isEmpty);
  });

  test(
    'card refresh keeps dirty rows and does not revive tombstones',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final local = LocalDeckStore(database.db);
      await local.refreshDeckMeta(const [deck]);
      await local.mirrorCards('deck', [card('dirty'), card('deleted')]);
      await local.updateCardContent(
        id: 'dirty',
        front: 'local edit',
        back: 'answer',
        keywords: const [],
        isConcept: false,
      );
      await local.deleteCard('deleted');

      await local.mirrorCards('deck', [
        card('dirty', front: 'server edit'),
        card('deleted'),
      ]);

      final visible = await local.cards('deck');
      expect(visible.map((value) => value.id), ['dirty']);
      expect(visible.single.front, 'local edit');
      expect(await local.cardDeletions(), hasLength(1));
    },
  );

  test(
    'metadata refresh keeps dirty records and excludes tombstones',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final decks = LocalDeckStore(database.db);
      final courses = LocalCourseStore(database.db);
      final now = DateTime.utc(2026);
      Course course(String id, String name) => Course(
        id: id,
        userId: 'user',
        name: name,
        accentColor: 'slate',
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      );
      DeckSummary summary(String id, String name) => DeckSummary(
        id: id,
        name: name,
        lastStudiedAt: null,
        totalCards: 0,
        dueCards: 0,
        masteryPercent: 0,
      );

      await courses.refreshCourses([
        course('dirty-course', 'before'),
        course('deleted-course', 'before'),
      ]);
      await courses.updateCourse(id: 'dirty-course', name: 'local course');
      await courses.deleteCourse(
        'deleted-course',
        defaultCourseId: 'dirty-course',
      );
      await courses.refreshCourses([
        course('dirty-course', 'server course'),
        course('deleted-course', 'server course'),
      ]);

      await decks.refreshDeckMeta([
        summary('dirty-deck', 'before'),
        summary('deleted-deck', 'before'),
      ]);
      await decks.updateDeck(id: 'dirty-deck', name: 'local deck');
      await decks.deleteDeck('deleted-deck');
      await decks.refreshDeckMeta([
        summary('dirty-deck', 'server deck'),
        summary('deleted-deck', 'server deck'),
      ]);

      expect((await courses.cachedCourses()).map((value) => value.name), [
        'local course',
      ]);
      expect((await decks.cachedDeckSummaries()).map((value) => value.name), [
        'local deck',
      ]);
      expect(await courses.courseDeletions(), hasLength(1));
      expect(await decks.deckDeletions(), hasLength(1));
    },
  );
}
