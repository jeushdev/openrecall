import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/application/decks_tab_view.dart';
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
