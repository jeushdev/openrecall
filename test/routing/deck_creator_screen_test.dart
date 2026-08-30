import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/routing/placeholders/deck_creator_screen.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../support/fake_course_repository.dart';
import '../support/fake_deck_repository.dart';

FakeCourseRepository _courses() => FakeCourseRepository(courses: [
      fakeCourse(id: 'course-1', name: 'Biology', isDefault: true),
      fakeCourse(id: 'course-2', name: 'History'),
    ]);

/// Pumps the screen pushed on top of a stub `/` so `context.pop()` has a target.
Future<void> _pump(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  FakeCourseRepository? courses,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: '/deck-creator',
        builder: (_, _) => const DeckCreatorScreen(),
      ),
      GoRoute(
        path: AppRoutes.deckDetailPath,
        name: AppRoutes.deckDetailName,
        builder: (_, state) => Scaffold(
          body: Text('deck-detail ${state.pathParameters['deckId']}'),
        ),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      deckRepositoryProvider.overrideWithValue(decks),
      courseRepositoryProvider.overrideWithValue(courses ?? _courses()),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  router.push('/deck-creator');
  await tester.pumpAndSettle();
}

bool _createEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Create')).onPressed !=
    null;

void main() {
  testWidgets('Create is disabled with a course picked but no name',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository());

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();

    expect(_createEnabled(tester), isFalse);
  });

  testWidgets('Create is enabled with a name and no course (course is optional)',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository());

    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.pumpAndSettle();

    expect(_createEnabled(tester), isTrue);
  });

  testWidgets('Create enables once a name is set, with or without a course',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository());

    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();

    expect(_createEnabled(tester), isTrue);
  });

  testWidgets(
      'offline (course list unavailable): shows a note, Create still works with '
      'no course id', (tester) async {
    final decks = FakeDeckRepository();
    final courses = _courses()..throwOnNextCall = StateError('offline');
    await _pump(tester, decks: decks, courses: courses);

    expect(find.textContaining('goes to your default course'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.pumpAndSettle();
    expect(_createEnabled(tester), isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(decks.calls, contains('createDeck(Cells)'));
    expect(find.text('deck-detail deck-1'), findsOneWidget);
  });

  testWidgets(
      'Create calls createDeck with the name and course id, then opens deck detail',
      (tester) async {
    final decks = FakeDeckRepository();
    await _pump(tester, decks: decks);

    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(decks.calls, contains('createDeck(Cells, course=course-2)'));
    // The freshly-created deck's id (FakeDeckRepository mints 'deck-1').
    expect(find.text('deck-detail deck-1'), findsOneWidget);
    expect(find.byType(DeckCreatorScreen), findsNothing);
  });

  testWidgets('a failed create shows an inline error and re-enables the form',
      (tester) async {
    final decks = FakeDeckRepository()..throwOnNextCall = StateError('offline');
    await _pump(tester, decks: decks);

    await tester.enterText(find.byType(TextField), 'Cells');
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't create the deck"), findsOneWidget);
    expect(find.byType(DeckCreatorScreen), findsOneWidget);
    expect(_createEnabled(tester), isTrue);
  });
}
