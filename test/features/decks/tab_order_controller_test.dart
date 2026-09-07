import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';
import 'package:open_recall/features/decks/data/cache_first_deck_repository.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/deck.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/local_db_harness.dart';

DeckSummary _deck(String id, {String? courseId, int position = 0}) =>
    DeckSummary(
      id: id,
      name: id,
      courseId: courseId,
      lastStudiedAt: null,
      totalCards: 0,
      dueCards: 0,
      masteryPercent: 0,
      position: position,
    );

Course _course(String id, {bool isDefault = false, int position = 0}) => Course(
  id: id,
  userId: 'user-1',
  name: id,
  accentColor: 'slate',
  isDefault: isDefault,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  position: position,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalDbTestFfi);

  Future<ProviderContainer> boot(
    FakeDeckRepository decks,
    FakeCourseRepository courses,
  ) async {
    final container = ProviderContainer(
      overrides: [
        deckRepositoryProvider.overrideWithValue(decks),
        courseRepositoryProvider.overrideWithValue(courses),
      ],
    );
    addTearDown(container.dispose);
    container.listen(decksProvider, (_, _) {}, fireImmediately: true);
    container.listen(coursesProvider, (_, _) {}, fireImmediately: true);
    await container.read(tabDecksProvider.future);
    await container.read(coursesProvider.future);
    return container;
  }

  List<String> deckIdsOf(ProviderContainer c, String courseId) => c
      .read(decksTabViewProvider)
      .requireValue
      .firstWhere((g) => g.course.id == courseId)
      .decks
      .map((d) => d.id)
      .toList();

  List<String> courseIdsOf(ProviderContainer c) => c
      .read(decksTabViewProvider)
      .requireValue
      .map((g) => g.course.id)
      .toList();

  group('TabOrderController.reorderDecks', () {
    test(
      'applies the new deck order optimistically, then persists it',
      () async {
        final decks = FakeDeckRepository(
          decks: [
            _deck('d1', courseId: 'c1', position: 0),
            _deck('d2', courseId: 'c1', position: 1),
            _deck('d3', courseId: 'c1', position: 2),
          ],
        );
        final container = await boot(
          decks,
          FakeCourseRepository(courses: [_course('c1', isDefault: true)]),
        );

        await container.read(tabOrderProvider.notifier).reorderDecks('c1', [
          'd3',
          'd1',
          'd2',
        ]);

        expect(deckIdsOf(container, 'c1'), ['d3', 'd1', 'd2']);
        expect(decks.calls, contains('reorderDecks([d3, d1, d2])'));
      },
    );

    test('reverts to the previous deck order when the persist fails', () async {
      final decks = FakeDeckRepository(
        decks: [
          _deck('d1', courseId: 'c1', position: 0),
          _deck('d2', courseId: 'c1', position: 1),
          _deck('d3', courseId: 'c1', position: 2),
        ],
      );
      final container = await boot(
        decks,
        FakeCourseRepository(courses: [_course('c1', isDefault: true)]),
      );
      decks.throwOnNextCall = StateError('offline');

      await container.read(tabOrderProvider.notifier).reorderDecks('c1', [
        'd3',
        'd1',
        'd2',
      ]);

      expect(deckIdsOf(container, 'c1'), ['d1', 'd2', 'd3']);
      expect(container.read(tabOrderProvider).deckOrders, isEmpty);
    });

    test('offline, a queued deck drag keeps its new order after the settle '
        '(milestone E3)', () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final store = LocalDeckStore(database.db);
      await store.pinDeck(deckId: 'd1', name: 'd1', courseId: 'c1');
      await store.pinDeck(deckId: 'd2', name: 'd2', courseId: 'c1');
      await store.pinDeck(deckId: 'd3', name: 'd3', courseId: 'c1');

      final remote = FakeDeckRepository()..alwaysThrow = StateError('offline');
      final container = ProviderContainer(
        overrides: [
          localDeckStoreProvider.overrideWithValue(store),
          deckRepositoryProvider.overrideWithValue(
            CacheFirstDeckRepository(remote, store, LocalCourseStore(null)),
          ),
          courseRepositoryProvider.overrideWithValue(
            FakeCourseRepository(courses: [_course('c1', isDefault: true)]),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(decksProvider, (_, _) {}, fireImmediately: true);
      container.listen(coursesProvider, (_, _) {}, fireImmediately: true);
      await container.read(tabDecksProvider.future);
      await container.read(coursesProvider.future);

      await container.read(tabOrderProvider.notifier).reorderDecks('c1', [
        'd3',
        'd1',
        'd2',
      ]);

      expect(deckIdsOf(container, 'c1'), ['d3', 'd1', 'd2']);
      expect(
        container.read(tabOrderProvider).deckOrders,
        isEmpty,
        reason: 'the persist did not throw, so the override is cleared',
      );
      expect((await store.unsyncedDecks()).map((d) => d.id).toSet(), {
        'd1',
        'd2',
        'd3',
      }, reason: 'the new order is queued for the reconnect push');
    });
  });

  group('TabOrderController.reorderCourses', () {
    test(
      'applies the new course order optimistically, then persists it',
      () async {
        final container = await boot(
          FakeDeckRepository(),
          FakeCourseRepository(
            courses: [
              _course('c1', isDefault: true, position: 0),
              _course('c2', position: 1),
              _course('c3', position: 2),
            ],
          ),
        );

        await container.read(tabOrderProvider.notifier).reorderCourses([
          'c1',
          'c3',
          'c2',
        ]);

        expect(courseIdsOf(container), ['c1', 'c3', 'c2']);
      },
    );

    test(
      'reverts to the previous course order when the persist fails',
      () async {
        final courses = FakeCourseRepository(
          courses: [
            _course('c1', isDefault: true, position: 0),
            _course('c2', position: 1),
            _course('c3', position: 2),
          ],
        );
        final container = await boot(FakeDeckRepository(), courses);
        courses.throwOnNextCall = StateError('offline');

        await container.read(tabOrderProvider.notifier).reorderCourses([
          'c1',
          'c3',
          'c2',
        ]);

        expect(courseIdsOf(container), ['c1', 'c2', 'c3']);
        expect(container.read(tabOrderProvider).courseOrder, isNull);
      },
    );
  });
}
