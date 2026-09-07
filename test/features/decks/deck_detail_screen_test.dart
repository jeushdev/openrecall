import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/deck_detail_screen.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';

DeckSummary _deck(
  String id, {
  String name = 'Cell structure',
  String? courseId,
  int cards = 0,
}) => DeckSummary(
  id: id,
  name: name,
  courseId: courseId,
  lastStudiedAt: null,
  totalCards: cards,
  dueCards: 0,
  masteryPercent: 0,
);

FlashCard _card({
  String id = 'card-1',
  String front = 'Capital of France',
  String back = 'Paris',
  List<String> keywords = const [],
  bool isConcept = false,
}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: keywords,
  isConcept: isConcept,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

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

List<Course> _courses() => [
  fakeCourse(id: 'c-default', name: 'Uncategorized', isDefault: true),
  fakeCourse(id: 'c-bio', name: 'Biology'),
];

/// Pumps [DeckDetailScreen] for `deck-1`, pushed on top of a `/` stub so
/// `context.pop()` (delete) has a target. Returns the router so a test can keep
/// navigating.
Future<GoRouter> _pump(
  WidgetTester tester,
  _Recorder rec, {
  required FakeDeckRepository decks,
  FakeCourseRepository? courses,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: AppRoutes.deckDetailPath,
        name: AppRoutes.deckDetailName,
        builder: (_, state) =>
            DeckDetailScreen(deckId: state.pathParameters['deckId']!),
      ),
      GoRoute(
        path: AppRoutes.studySessionPath,
        name: AppRoutes.studySessionName,
        builder: (_, state) {
          rec.location = state.uri.toString();
          return const Scaffold(body: Text('study stub'));
        },
      ),
      GoRoute(
        path: AppRoutes.importCardsPath,
        name: AppRoutes.importCardsName,
        builder: (_, state) {
          rec.location = state.uri.toString();
          return const Scaffold(body: Text('import stub'));
        },
      ),
      GoRoute(
        path: AppRoutes.cardListPath,
        name: AppRoutes.cardListName,
        builder: (_, state) {
          rec.location = state.uri.toString();
          return const Scaffold(body: Text('cards stub'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deckRepositoryProvider.overrideWithValue(decks),
        courseRepositoryProvider.overrideWithValue(
          courses ?? FakeCourseRepository(courses: _courses()),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  router.push('/deck/deck-1');
  await tester.pumpAndSettle();
  return router;
}

Future<void> _openOverflow(WidgetTester tester, String item) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the deck name in the app bar', (tester) async {
    await _pump(
      tester,
      _Recorder(),
      decks: FakeDeckRepository(
        decks: [_deck('deck-1', name: 'Cell structure')],
      ),
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Cell structure'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Import action routes to /deck/:deckId/import', (
    tester,
  ) async {
    final rec = _Recorder();
    await _pump(
      tester,
      rec,
      decks: FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]),
    );

    await tester.tap(find.byIcon(Icons.file_download_outlined));
    await tester.pumpAndSettle();

    expect(rec.location, '/deck/deck-1/import');
  });

  testWidgets('picking a study mode starts a session for the deck', (
    tester,
  ) async {
    final rec = _Recorder();
    await _pump(
      tester,
      rec,
      decks: FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]),
    );

    await tester.tap(find.text('Flip & Rate'));
    await tester.pumpAndSettle();

    expect(rec.location, '/study/deck-1');
  });

  testWidgets('the View cards row shows the count and opens the card list', (
    tester,
  ) async {
    final rec = _Recorder();
    await _pump(
      tester,
      rec,
      decks: FakeDeckRepository(
        decks: [_deck('deck-1')],
        cards: [
          _card(),
          _card(id: 'card-2'),
        ],
      ),
    );

    expect(find.text('View cards (2)'), findsOneWidget);

    await tester.tap(find.text('View cards (2)'));
    await tester.pumpAndSettle();

    expect(rec.location, '/deck/deck-1/cards');
  });

  testWidgets('an empty deck offers an Add cards CTA into import', (
    tester,
  ) async {
    final rec = _Recorder();
    await _pump(
      tester,
      rec,
      decks: FakeDeckRepository(decks: [_deck('deck-1')]),
    );

    await tester.tap(find.text('Add cards'));
    await tester.pumpAndSettle();

    expect(rec.location, '/deck/deck-1/import');
  });

  testWidgets('Edit deck renames the deck through DecksController', (
    tester,
  ) async {
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1', name: 'Old name', courseId: 'c-default')],
      cards: [_card()],
    );
    await _pump(tester, _Recorder(), decks: decks);

    await _openOverflow(tester, 'Edit deck');

    await tester.enterText(find.byType(TextField), 'New name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('updateDeck(id=deck-1, name=New name, course=c-default)'),
    );
  });

  testWidgets('Edit deck stays reachable above the keyboard at 360x640', (
    tester,
  ) async {
    _configurePhone(tester, const Size(360, 640));
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1', name: 'Old name', courseId: 'c-default')],
      cards: [_card()],
    );
    await _pump(tester, _Recorder(), decks: decks);

    await _openOverflow(tester, 'Edit deck');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Responsive deck');
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(
      save,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bounded-bottom-sheet-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(360));
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('updateDeck(id=deck-1, name=Responsive deck, course=c-default)'),
    );
  });

  testWidgets('Edit deck keeps a long selected course readable at 2x text', (
    tester,
  ) async {
    _configurePhone(tester, const Size(320, 568));
    const courseName = 'Advanced cellular and molecular biology';
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1', name: 'Old name', courseId: 'course-long')],
      cards: [_card()],
    );
    await _pump(
      tester,
      _Recorder(),
      decks: decks,
      courses: FakeCourseRepository(
        courses: [fakeCourse(id: 'course-long', name: courseName)],
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);

    await _openOverflow(tester, 'Edit deck');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Responsive deck');
    final sheetScroll = find.descendant(
      of: find.byKey(const ValueKey('bounded-bottom-sheet-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(courseName),
      100,
      scrollable: sheetScroll.first,
    );
    expect(tester.widget<Text>(find.text(courseName)).maxLines, isNull);
    expect(tester.takeException(), isNull);

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(save, 100, scrollable: sheetScroll.first);
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      decks.calls,
      contains(
        'updateDeck(id=deck-1, name=Responsive deck, course=course-long)',
      ),
    );
  });

  testWidgets('all study modes remain reachable at 320x568 and 2x text', (
    tester,
  ) async {
    _configurePhone(tester, const Size(320, 568));
    final rec = _Recorder();
    await _pump(
      tester,
      rec,
      decks: FakeDeckRepository(
        decks: [_deck('deck-1')],
        cards: [
          _card(keywords: const ['Paris']),
          _card(id: 'concept', isConcept: true),
        ],
      ),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final feynman = find.text('Feynman Synthesis');
    await tester.scrollUntilVisible(
      feynman,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('pre-session-picker-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(feynman.hitTestable(), findsOneWidget);
    await tester.tap(feynman);
    await tester.pumpAndSettle();
    expect(rec.location, '/study/deck-1');
  });

  testWidgets('Edit deck can move the deck to another course', (tester) async {
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1', name: 'Cells', courseId: 'c-default')],
      cards: [_card()],
    );
    await _pump(tester, _Recorder(), decks: decks);

    await _openOverflow(tester, 'Edit deck');
    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('updateDeck(id=deck-1, name=Cells, course=c-bio)'),
    );
  });

  testWidgets('Delete deck confirms, calls deleteDeck, then pops to the tab', (
    tester,
  ) async {
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1')],
      cards: [_card()],
    );
    await _pump(tester, _Recorder(), decks: decks);

    await _openOverflow(tester, 'Delete deck');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(decks.calls, contains('deleteDeck(deck-1)'));
    expect(find.byType(DeckDetailScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Delete deck can be cancelled', (tester) async {
    final decks = FakeDeckRepository(
      decks: [_deck('deck-1')],
      cards: [_card()],
    );
    await _pump(tester, _Recorder(), decks: decks);

    await _openOverflow(tester, 'Delete deck');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(decks.calls.where((c) => c.startsWith('deleteDeck')), isEmpty);
    expect(find.byType(DeckDetailScreen), findsOneWidget);
  });
}
