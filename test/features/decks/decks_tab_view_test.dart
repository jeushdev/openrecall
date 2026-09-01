import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';
import 'package:open_recall/features/decks/application/offline_providers.dart';
import 'package:open_recall/features/decks/application/pending_deletions.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';

DeckSummary _deck(String id, {String? courseId, int cards = 0}) => DeckSummary(
      id: id,
      name: id,
      courseId: courseId,
      lastStudiedAt: null,
      totalCards: cards,
      dueCards: 0,
      masteryPercent: 0,
    );

Course _course(
  String id, {
  String? name,
  String accentColor = 'slate',
  bool isDefault = false,
  DateTime? createdAt,
}) =>
    Course(
      id: id,
      userId: 'user-1',
      name: name ?? id,
      accentColor: accentColor,
      isDefault: isDefault,
      createdAt: createdAt ?? DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// Two cached deck headers; only `cached-1` has its cards mirrored.
class _SeededLocalDeckStore extends LocalDeckStore {
  _SeededLocalDeckStore() : super(null);

  @override
  bool get isNoop => false;

  @override
  Future<List<DeckSummary>> cachedDeckSummaries() async => const [
        DeckSummary(
          id: 'cached-1',
          name: 'Cached deck',
          lastStudiedAt: null,
          totalCards: 3,
          dueCards: 3,
          masteryPercent: 0,
        ),
        DeckSummary(
          id: 'cached-2',
          name: 'Locked deck',
          lastStudiedAt: null,
          totalCards: 0,
          dueCards: 0,
          masteryPercent: 0,
        ),
      ];

  @override
  Future<Set<String>> mirroredCardDeckIds() async => {'cached-1'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decksTabViewProvider — course grouping', () {
    Future<List<CourseDeckGroup>> groupsOf({
      required List<DeckSummary> decks,
      required List<Course> courses,
    }) async {
      final container = ProviderContainer(overrides: [
        deckRepositoryProvider
            .overrideWithValue(FakeDeckRepository(decks: decks)),
        courseRepositoryProvider
            .overrideWithValue(FakeCourseRepository(courses: courses)),
      ]);
      addTearDown(container.dispose);
      await container.read(tabDecksProvider.future);
      await container.read(coursesProvider.future);
      return container.read(decksTabViewProvider).requireValue;
    }

    test('orders groups by course.createdAt, default course first', () async {
      final groups = await groupsOf(
        decks: [
          _deck('d-bio', courseId: 'c-bio', cards: 3),
          _deck('d-home', courseId: 'c-default'),
        ],
        courses: [
          _course('c-bio', name: 'Biology', createdAt: DateTime.utc(2026, 3)),
          _course('c-default',
              name: 'Uncategorized',
              isDefault: true,
              createdAt: DateTime.utc(2026, 1)),
        ],
      );

      expect(groups.map((g) => g.course.name), ['Uncategorized', 'Biology']);
      expect(groups[0].decks.map((d) => d.id), ['d-home']);
      expect(groups[1].decks.single.cardCount, 3);
      expect(groups[1].decks.single.accentKey, 'slate');
    });

    test('includes a course with no decks', () async {
      final groups = await groupsOf(
        decks: [_deck('d1', courseId: 'c1')],
        courses: [
          _course('c1', name: 'Full', createdAt: DateTime.utc(2026, 1)),
          _course('c2', name: 'Empty', createdAt: DateTime.utc(2026, 2)),
        ],
      );

      expect(groups.map((g) => g.course.name), ['Full', 'Empty']);
      expect(groups[1].decks, isEmpty);
    });

    test('a deck with an unknown course id falls into the default group',
        () async {
      final groups = await groupsOf(
        decks: [
          _deck('orphan', courseId: 'gone'),
          _deck('orphan-null'),
        ],
        courses: [
          _course('c-default',
              name: 'Uncategorized',
              isDefault: true,
              createdAt: DateTime.utc(2026, 1)),
          _course('c-other', name: 'Other', createdAt: DateTime.utc(2026, 2)),
        ],
      );

      expect(groups[0].course.isDefault, isTrue);
      expect(groups[0].decks.map((d) => d.id), ['orphan', 'orphan-null']);
      expect(groups[1].decks, isEmpty);
    });

    test('with no courses loaded, every deck lands in one synthetic group',
        () async {
      final groups = await groupsOf(
        decks: [_deck('d1', courseId: 'c1'), _deck('d2')],
        courses: const [],
      );

      expect(groups, hasLength(1));
      expect(groups.single.decks.map((d) => d.id), ['d1', 'd2']);
    });
  });

  group('decksTabViewProvider — optimistic deletions (milestone R1)', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer(overrides: [
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository(decks: [
          _deck('d-bio', courseId: 'c-bio'),
          _deck('d-chem', courseId: 'c-chem'),
          _deck('d-home', courseId: 'c-default'),
        ])),
        courseRepositoryProvider
            .overrideWithValue(FakeCourseRepository(courses: [
          _course('c-default',
              name: 'Uncategorized',
              isDefault: true,
              createdAt: DateTime.utc(2026, 1)),
          _course('c-bio', name: 'Biology', createdAt: DateTime.utc(2026, 2)),
          _course('c-chem', name: 'Chemistry', createdAt: DateTime.utc(2026, 3)),
        ])),
      ]);
      addTearDown(container.dispose);
      await container.read(tabDecksProvider.future);
      await container.read(coursesProvider.future);
    });

    List<CourseDeckGroup> currentGroups() =>
        container.read(decksTabViewProvider).requireValue;

    test('a pending-deleted course drops out and its decks re-home under the '
        'default course', () {
      container.read(pendingDeletionsProvider.notifier).addCourse('c-bio');

      final groups = currentGroups();
      expect(groups.map((g) => g.course.name), ['Uncategorized', 'Chemistry']);
      expect(
        groups.firstWhere((g) => g.course.isDefault).decks.map((d) => d.id),
        containsAll(['d-home', 'd-bio']),
      );
    });

    test('a pending-deleted deck drops out of its group', () {
      container.read(pendingDeletionsProvider.notifier).addDeck('d-chem');

      final chem =
          currentGroups().firstWhere((g) => g.course.name == 'Chemistry');
      expect(chem.decks, isEmpty);
    });

    test('clearing the pending id brings the row back', () {
      final pending = container.read(pendingDeletionsProvider.notifier);
      pending.addDeck('d-chem');
      expect(
        currentGroups()
            .firstWhere((g) => g.course.name == 'Chemistry')
            .decks,
        isEmpty,
      );

      pending.removeDeck('d-chem');
      expect(
        currentGroups()
            .firstWhere((g) => g.course.name == 'Chemistry')
            .decks
            .map((d) => d.id),
        ['d-chem'],
      );
    });
  });

  group('decksTabViewProvider — offline (milestone E1)', () {
    test('serves cached decks while the Supabase refresh is still in flight',
        () async {
      final container = ProviderContainer(overrides: [
        deckRepositoryProvider
            .overrideWithValue(FakeDeckRepository()..hangForever = true),
        courseRepositoryProvider
            .overrideWithValue(FakeCourseRepository(courses: const [])),
        localDeckStoreProvider.overrideWithValue(_SeededLocalDeckStore()),
      ]);
      addTearDown(container.dispose);

      await container.read(cachedTabDecksProvider.future);
      final groups = container.read(decksTabViewProvider).requireValue;

      expect(groups.single.decks.map((d) => d.name), ['Cached deck', 'Locked deck']);
    });

    test('offline, a deck with no mirrored cards is flagged locked', () async {
      final container = ProviderContainer(overrides: [
        deckRepositoryProvider
            .overrideWithValue(FakeDeckRepository()..hangForever = true),
        courseRepositoryProvider
            .overrideWithValue(FakeCourseRepository(courses: const [])),
        localDeckStoreProvider.overrideWithValue(_SeededLocalDeckStore()),
        onlineStatusProvider.overrideWith((ref) => Stream.value(false)),
        studiableOfflineDeckIdsProvider
            .overrideWith((ref) async => const <String>{'cached-1'}),
      ]);
      addTearDown(container.dispose);
      container.listen(onlineStatusProvider, (_, _) {}, fireImmediately: true);

      await container.read(cachedTabDecksProvider.future);
      await container.read(onlineStatusProvider.future);
      await container.read(studiableOfflineDeckIdsProvider.future);
      final decks = container.read(decksTabViewProvider).requireValue.single.decks;

      expect(decks.firstWhere((d) => d.id == 'cached-1').isLockedOffline, isFalse);
      expect(decks.firstWhere((d) => d.id == 'cached-2').isLockedOffline, isTrue);
    });

    test('online, no deck is ever locked whatever is mirrored', () async {
      final container = ProviderContainer(overrides: [
        deckRepositoryProvider
            .overrideWithValue(FakeDeckRepository()..hangForever = true),
        courseRepositoryProvider
            .overrideWithValue(FakeCourseRepository(courses: const [])),
        localDeckStoreProvider.overrideWithValue(_SeededLocalDeckStore()),
        onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
        studiableOfflineDeckIdsProvider
            .overrideWith((ref) async => const <String>{}),
      ]);
      addTearDown(container.dispose);
      container.listen(onlineStatusProvider, (_, _) {}, fireImmediately: true);

      await container.read(cachedTabDecksProvider.future);
      await container.read(onlineStatusProvider.future);
      await container.read(studiableOfflineDeckIdsProvider.future);
      final decks = container.read(decksTabViewProvider).requireValue.single.decks;

      expect(decks.every((d) => !d.isLockedOffline), isTrue);
    });
  });

  group('ExpandedCoursesController — persistence', () {
    Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
      SharedPreferences.setMockInitialValues(initial);
      final sp = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        decksAccordionPreferencesProvider
            .overrideWithValue(DecksAccordionPreferences(sp)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('build() is null before the user has toggled anything', () async {
      final c = await containerWith({});
      expect(await c.read(expandedCoursesProvider.future), isNull);
    });

    test('setExpanded persists and a fresh build reads it back', () async {
      final c = await containerWith({});
      await c.read(expandedCoursesProvider.future);

      await c
          .read(expandedCoursesProvider.notifier)
          .setExpanded({'c-1', 'c-2'});

      expect(c.read(expandedCoursesProvider).asData?.value, {'c-1', 'c-2'});

      c.invalidate(expandedCoursesProvider);
      expect(await c.read(expandedCoursesProvider.future), {'c-1', 'c-2'});
    });
  });
}
