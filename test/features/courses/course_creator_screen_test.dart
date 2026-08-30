import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/presentation/course_creator_screen.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';

/// Pumps the screen pushed on top of a stub `/` so `context.pop()` has a target.
Future<void> _pump(
  WidgetTester tester, {
  required FakeCourseRepository courses,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: AppRoutes.courseCreatorPath,
        builder: (_, _) => const CourseCreatorScreen(),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      courseRepositoryProvider.overrideWithValue(courses),
      deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  router.push(AppRoutes.courseCreatorPath);
  await tester.pumpAndSettle();
}

bool _createEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Create'))
        .onPressed !=
    null;

Finder _check(String accentKey) => find.descendant(
      of: find.byKey(ValueKey('accent-$accentKey')),
      matching: find.byIcon(Icons.check),
    );

void main() {
  testWidgets('renders a name field and all eight accent swatches',
      (tester) async {
    await _pump(tester, courses: FakeCourseRepository());

    expect(find.byType(TextField), findsOneWidget);
    for (final key in const [
      'slate',
      'red',
      'amber',
      'green',
      'teal',
      'blue',
      'violet',
      'pink',
    ]) {
      expect(find.byKey(ValueKey('accent-$key')), findsOneWidget, reason: key);
    }
  });

  testWidgets('Create is disabled until a non-empty name is typed',
      (tester) async {
    await _pump(tester, courses: FakeCourseRepository());

    expect(_createEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'Chemistry');
    await tester.pump();

    expect(_createEnabled(tester), isTrue);
  });

  testWidgets('slate is selected by default; tapping another swatch moves it',
      (tester) async {
    await _pump(tester, courses: FakeCourseRepository());

    expect(_check('slate'), findsOneWidget);
    expect(_check('green'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('accent-green')));
    await tester.pump();

    expect(_check('slate'), findsNothing);
    expect(_check('green'), findsOneWidget);
  });

  testWidgets('Create forwards the name and accent, then pops to the Decks tab',
      (tester) async {
    final courses = FakeCourseRepository();
    await _pump(tester, courses: courses);

    await tester.enterText(find.byType(TextField), 'Chemistry');
    await tester.tap(find.byKey(const ValueKey('accent-amber')));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(courses.calls, contains('createCourse(name=Chemistry, accent=amber)'));
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(CourseCreatorScreen), findsNothing);
  });

  testWidgets('a failed create shows a snackbar and keeps the form',
      (tester) async {
    final courses = FakeCourseRepository()
      ..throwOnNextCall = StateError('offline');
    await _pump(tester, courses: courses);

    await tester.enterText(find.byType(TextField), 'Chemistry');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't create the course"), findsOneWidget);
    expect(find.byType(CourseCreatorScreen), findsOneWidget);
    expect(_createEnabled(tester), isTrue);
  });
}
