import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
}) =>
    Course(
      id: id,
      userId: 'user-1',
      name: name,
      accentColor: 'slate',
      isDefault: isDefault,
      createdAt: createdAt ?? DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
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
        path: '/study/:deckId',
        name: 'study-session',
        builder: (context, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('study stub'));
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
    expect(find.text('1 decks'), findsOneWidget);
    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('2 decks'), findsOneWidget);
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

  testWidgets('tapping a deck routes to /study/:deckId with no scope',
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

    expect(recorder.location, '/study/deck-1');
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
}
