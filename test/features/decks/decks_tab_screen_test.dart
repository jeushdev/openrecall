import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/decks_tab_screen.dart';
import 'package:open_recall/features/decks/presentation/widgets/deck_grid_tile.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';

DeckSummary _deck(
  String id, {
  String? name,
  String? courseId,
  int cards = 0,
}) =>
    DeckSummary(
      id: id,
      name: name ?? id,
      courseId: courseId,
      lastStudiedAt: null,
      totalCards: cards,
      dueCards: 0,
      masteryPercent: 0,
    );

Course _course(
  String id, {
  required String name,
  bool isDefault = false,
  DateTime? createdAt,
  int position = 0,
}) =>
    Course(
      id: id,
      userId: 'user-1',
      name: name,
      accentColor: 'slate',
      isDefault: isDefault,
      createdAt: createdAt ?? DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      position: position,
    );

/// A default "Uncategorized" course (created first) plus "Biology".
List<Course> _courses() => [
      _course('c-default',
          name: 'Uncategorized',
          isDefault: true,
          createdAt: DateTime.utc(2026, 1)),
      _course('c-bio', name: 'Biology', createdAt: DateTime.utc(2026, 2)),
    ];

class _Recorder {
  String? location;
}

void _configurePhone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

Widget _host(
  _Recorder recorder, {
  required FakeDeckRepository decks,
  FakeCourseRepository? courses,
}) {
  final router = GoRouter(
    initialLocation: '/decks',
    routes: [
      GoRoute(
        path: '/decks',
        builder: (context, state) => const DecksTabScreen(),
      ),
      GoRoute(
        path: '/deck/:deckId',
        name: 'deck-detail',
        builder: (context, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('deck-detail stub'));
        },
      ),
      GoRoute(
        path: '/deck-creator',
        name: 'deck-creator',
        builder: (context, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('creator stub'));
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      deckRepositoryProvider.overrideWithValue(decks),
      courseRepositoryProvider.overrideWithValue(
        courses ?? FakeCourseRepository(courses: _courses()),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('renders a header per course with its deck count', (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [
        _deck('d1', name: 'Cell structure', courseId: 'c-bio'),
        _deck('d2', name: 'Photosynthesis', courseId: 'c-bio'),
        _deck('d3', name: 'Shopping list', courseId: 'c-default'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Uncategorized'), findsOneWidget);
    expect(find.text('1 deck'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('2 decks'), findsOneWidget);
  });

  testWidgets('the + action opens the Create menu', (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('d1', courseId: 'c-bio')]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('decks-create')));
    await tester.pumpAndSettle();

    expect(find.text('Create deck'), findsOneWidget);
  });

  testWidgets('the chevron lines up whether or not the header carries a ⋮ menu '
      '(milestone R2)', (tester) async {
    // A course with a menu (real) and one without (the synthetic fallback shown
    // while courses load) must place the expand chevron at the same offset from
    // the right edge — the header reserves a fixed-width trailing menu slot.
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('d1', courseId: 'c-bio')]),
    ));
    await tester.pumpAndSettle();
    final withMenu = tester.getRect(find.byIcon(Icons.expand_more).first).right;

    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('d1')]),
      courses: FakeCourseRepository()..throwOnNextCall = StateError('offline'),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert), findsNothing);
    final withoutMenu =
        tester.getRect(find.byIcon(Icons.expand_more).first).right;

    expect(withoutMenu, withMenu);
  });

  testWidgets('a long course name wraps to two lines with a tooltip '
      '(milestone R2)', (tester) async {
    const longName = 'Organic Chemistry and Biochemistry Fundamentals II';
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('d1', courseId: 'c-long')]),
      courses: FakeCourseRepository(courses: [
        _course('c-long', name: longName, isDefault: true),
      ]),
    ));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      find.ancestor(of: find.text(longName), matching: find.byType(Tooltip)),
      findsOneWidget,
    );
  });

  testWidgets('only the default course starts expanded', (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [
        _deck('d1', name: 'Cell structure', courseId: 'c-bio'),
        _deck('d3', name: 'Shopping list', courseId: 'c-default'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Shopping list'), findsOneWidget); // default → expanded
    expect(find.text('Cell structure'), findsNothing); // Biology → collapsed
  });

  testWidgets('tapping a course header toggles its body', (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [
        _deck('d1', name: 'Cell structure', courseId: 'c-bio'),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('Cell structure'), findsOneWidget);

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.text('Cell structure'), findsNothing);
  });

  testWidgets('the deck badge shows the card count', (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [
        _deck('d1', name: 'Full deck', courseId: 'c-default', cards: 3),
        _deck('d2', name: 'Fresh deck', courseId: 'c-default'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 cards'), findsOneWidget);
    expect(find.text('no cards yet'), findsOneWidget);
  });

  testWidgets('tapping a deck routes to /deck/:deckId (deck detail)',
      (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_host(
      recorder,
      decks: FakeDeckRepository(decks: [
        _deck('deck-1', name: 'Cell structure', courseId: 'c-default'),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cell structure'));
    await tester.pumpAndSettle();

    expect(recorder.location, '/deck/deck-1');
  });

  testWidgets('the Create tile routes to /deck-creator', (tester) async {
    final recorder = _Recorder();
    await tester.pumpWidget(_host(
      recorder,
      decks: FakeDeckRepository(decks: [
        _deck('deck-1', courseId: 'c-default'),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(recorder.location, '/deck-creator');
  });

  testWidgets('a deck-list failure shows an error with Retry', (tester) async {
    final decks = FakeDeckRepository()..throwOnNextCall = StateError('offline');
    await tester.pumpWidget(_host(_Recorder(), decks: decks));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your decks."), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    // Second fetch (throw already consumed) succeeds → error state clears.
    expect(find.text("Couldn't load your decks."), findsNothing);
  });

  group('drag-to-reorder (milestone B)', () {
    testWidgets('reordering a course row changes the visible course order',
        (tester) async {
      final courses = FakeCourseRepository(courses: [
        _course('c-a',
            name: 'Alpha', isDefault: true, createdAt: DateTime.utc(2026, 1)),
        _course('c-b', name: 'Bravo', createdAt: DateTime.utc(2026, 2)),
        _course('c-c', name: 'Charlie', createdAt: DateTime.utc(2026, 3)),
      ]);
      await tester.pumpWidget(_host(
        _Recorder(),
        decks: FakeDeckRepository(decks: [_deck('d1', courseId: 'c-a')]),
        courses: courses,
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.text('Charlie')).dy,
        greaterThan(tester.getCenter(find.text('Alpha')).dy),
      );

      // Drive the reorder the drag gesture would: move row 2 ("Charlie") to
      // the front. onReorderItem's newIndex is the post-removal destination.
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderItem!(2, 0);
      await tester.pumpAndSettle();

      expect(courses.calls, contains('reorderCourses([c-c, c-a, c-b])'));
      expect(
        tester.getCenter(find.text('Charlie')).dy,
        lessThan(tester.getCenter(find.text('Alpha')).dy),
      );
    });

    testWidgets('reordering deck tiles persists the new deck order',
        (tester) async {
      final decks = FakeDeckRepository(decks: [
        _deck('d1', name: 'One', courseId: 'c-default'),
        _deck('d2', name: 'Two', courseId: 'c-default'),
        _deck('d3', name: 'Three', courseId: 'c-default'),
      ]);
      await tester.pumpWidget(_host(_Recorder(), decks: decks));
      await tester.pumpAndSettle();

      final grid = tester.widget<ReorderableGridView>(
        find.byType(ReorderableGridView),
      );
      grid.onReorder(2, 0); // drag "Three" to the front
      await tester.pumpAndSettle();

      expect(decks.calls, contains('reorderDecks([d3, d1, d2])'));
      final ids = tester
          .widgetList<DeckGridTile>(find.byType(DeckGridTile))
          .map((t) => t.deck.id)
          .toList();
      expect(ids, ['d3', 'd1', 'd2']);
    });
  });

  testWidgets('renders nothing from the retired segmented control',
      (tester) async {
    await tester.pumpWidget(_host(
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('d1', courseId: 'c-default')]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Due'), findsNothing);
    expect(find.text('All'), findsNothing);
    expect(find.byType(DeckGridTile), findsOneWidget);
  });

  group('course management (ui-spec-v2 §7)', () {
    // Groups are ordered by course created_at ascending, so the ⋮ menus render
    // in that order: [0] = the default "Uncategorized", [1] = "Biology".
    Finder defaultMenu() => find.byIcon(Icons.more_vert).first;
    Finder bioMenu() => find.byIcon(Icons.more_vert).last;

    Future<void> pumpTab(WidgetTester tester, FakeCourseRepository courses) async {
      await tester.pumpWidget(_host(
        _Recorder(),
        decks: FakeDeckRepository(decks: [
          _deck('d1', name: 'Cell structure', courseId: 'c-bio'),
          _deck('d2', name: 'Shopping list', courseId: 'c-default'),
        ]),
        courses: courses,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a non-default course header offers Edit and Delete',
        (tester) async {
      await pumpTab(tester, FakeCourseRepository(courses: _courses()));

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();

      expect(find.text('Edit course'), findsOneWidget);
      expect(find.text('Delete course'), findsOneWidget);
    });

    testWidgets('the default course header offers Edit but not Delete',
        (tester) async {
      await pumpTab(tester, FakeCourseRepository(courses: _courses()));

      await tester.tap(defaultMenu());
      await tester.pumpAndSettle();

      expect(find.text('Edit course'), findsOneWidget);
      expect(find.text('Delete course'), findsNothing);
    });

    testWidgets('Delete course confirms, then calls deleteCourse',
        (tester) async {
      final courses = FakeCourseRepository(courses: _courses());
      await pumpTab(tester, courses);

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete course'));
      await tester.pumpAndSettle();

      expect(find.text('Delete course?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(courses.calls, contains('deleteCourse(c-bio)'));
    });

    testWidgets(
        'deleting a course keeps the Decks tab mounted and removes the row '
        '(regression: the dialog must pop its own navigator, not the shell '
        'branch)', (tester) async {
      final courses = FakeCourseRepository(courses: _courses());
      final router = GoRouter(
        initialLocation: '/decks',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => shell,
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/decks',
                  builder: (_, _) => const DecksTabScreen(),
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/other',
                  builder: (_, _) => const Scaffold(body: Text('other')),
                ),
              ]),
            ],
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          deckRepositoryProvider.overrideWithValue(FakeDeckRepository(decks: [
            _deck('d1', name: 'Cell structure', courseId: 'c-bio'),
            _deck('d2', name: 'Shopping list', courseId: 'c-default'),
          ])),
          courseRepositoryProvider.overrideWithValue(courses),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete course'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(DecksTabScreen), findsOneWidget);
      expect(find.text('Decks'), findsOneWidget);
      expect(find.text('Biology'), findsNothing);
      expect(courses.calls, contains('deleteCourse(c-bio)'));
    });

    testWidgets('Delete course can be cancelled', (tester) async {
      final courses = FakeCourseRepository(courses: _courses());
      await pumpTab(tester, courses);

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete course'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(courses.calls.where((c) => c.startsWith('deleteCourse')), isEmpty);
    });

    testWidgets('Edit course renames and recolors through CourseController',
        (tester) async {
      final courses = FakeCourseRepository(courses: _courses());
      await pumpTab(tester, courses);

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit course'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Bio 101');
      await tester.tap(find.byKey(const ValueKey('accent-red')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        courses.calls,
        contains('updateCourse(id=c-bio, name=Bio 101, accent=red)'),
      );
    });

    testWidgets('Edit course stays reachable above the keyboard at 320x568',
        (tester) async {
      _configurePhone(tester, const Size(320, 568));
      final courses = FakeCourseRepository(courses: _courses());
      await pumpTab(tester, courses);

      await tester.tap(bioMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit course'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('accent-pink'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('accent-slate'))).dy,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Responsive Biology');
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('bounded-bottom-sheet-scroll')),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('accent-red')),
        120,
        scrollable: scrollable,
      );
      await tester.tap(find.byKey(const ValueKey('accent-red')));
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.scrollUntilVisible(save, 120, scrollable: scrollable);
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(288));
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        courses.calls,
        contains(
          'updateCourse(id=c-bio, name=Responsive Biology, accent=red)',
        ),
      );
    });

    testWidgets('the synthetic fallback course (courses still loading) has no menu',
        (tester) async {
      await pumpTab(tester, FakeCourseRepository()..throwOnNextCall = StateError('offline'));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
