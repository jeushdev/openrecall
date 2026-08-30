import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/import_cards_screen.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';

DeckSummary _deck(String id, {String name = 'Cell structure'}) => DeckSummary(
      id: id,
      name: name,
      courseId: null,
      lastStudiedAt: null,
      totalCards: 0,
      dueCards: 0,
      masteryPercent: 0,
    );

class _Recorder {
  String? location;
}

/// A viewport tall enough to hold the manual form + expanded bulk panel +
/// footer without scrolling, so every tap lands.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  _Recorder? rec,
}) async {
  final recorder = rec ?? _Recorder();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: AppRoutes.importCardsPath,
        name: AppRoutes.importCardsName,
        builder: (_, state) =>
            ImportCardsScreen(deckId: state.pathParameters['deckId']!),
      ),
      GoRoute(
        path: AppRoutes.studySessionPath,
        name: AppRoutes.studySessionName,
        builder: (_, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('study stub'));
        },
      ),
      GoRoute(
        path: AppRoutes.cardListPath,
        name: AppRoutes.cardListName,
        builder: (_, state) {
          recorder.location = state.uri.toString();
          return const Scaffold(body: Text('cards stub'));
        },
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [deckRepositoryProvider.overrideWithValue(decks)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  router.push('/deck/deck-1/import');
  await tester.pumpAndSettle();
}

bool _addCardEnabled(WidgetTester tester) => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add card'))
        .onPressed !=
    null;

Future<void> _enter(WidgetTester tester, String label, String text) =>
    tester.enterText(find.widgetWithText(TextFormField, label), text);

void main() {
  testWidgets('the app bar shows the deck name', (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: [_deck('deck-1', name: 'Mitochondria')]),
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mitochondria'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Add card is disabled until both Front and Back are filled',
      (tester) async {
    await _pump(tester, decks: FakeDeckRepository(decks: [_deck('deck-1')]));

    expect(_addCardEnabled(tester), isFalse);

    await _enter(tester, 'Front', 'Capital of France');
    await tester.pump();
    expect(_addCardEnabled(tester), isFalse);

    await _enter(tester, 'Back', 'Paris');
    await tester.pump();
    expect(_addCardEnabled(tester), isTrue);
  });

  testWidgets('a manual add writes the card, clears the fields and stays put',
      (tester) async {
    _useTallSurface(tester);
    final decks = FakeDeckRepository(decks: [_deck('deck-1')]);
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'Paris',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('addCard(deck=deck-1, front=Capital of France, back=Paris, '
          'keywords=[Paris], concept=false)'),
    );
    expect(find.text('Card added'), findsOneWidget);
    expect(find.byType(ImportCardsScreen), findsOneWidget);
    expect(find.text('Capital of France'), findsNothing);
    // The keyword chip is cleared too.
    expect(find.widgetWithText(InputChip, 'Paris'), findsNothing);
  });

  testWidgets('a keyword absent from Front and Back is rejected as a chip',
      (tester) async {
    _useTallSurface(tester);
    final decks = FakeDeckRepository(decks: [_deck('deck-1')]);
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'Berlin',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Keyword must appear in the front or back text.'),
        findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Berlin'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('addCard(deck=deck-1, front=Capital of France, back=Paris, '
          'keywords=[], concept=false)'),
    );
  });

  testWidgets('a failed manual write surfaces an error and keeps the text',
      (tester) async {
    final decks = FakeDeckRepository(decks: [_deck('deck-1')]);
    await _pump(tester, decks: decks);

    await _enter(tester, 'Front', 'Capital of France');
    await _enter(tester, 'Back', 'Paris');
    await tester.pump();
    // Arm the failure only now — the screen's initial `decksProvider` read
    // already consumed a `fetchDecks` call.
    decks.throwOnNextCall = StateError('offline');
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't save the card"), findsOneWidget);
    expect(find.text('Capital of France'), findsOneWidget);
  });

  testWidgets('the bulk panel starts open and flags bad lines after the debounce',
      (tester) async {
    _useTallSurface(tester);
    await _pump(tester, decks: FakeDeckRepository(decks: [_deck('deck-1')]));

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste FRONT | BACK lines here'),
      'Q1 | A1\nbroken line',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('1 ready'), findsOneWidget);
    expect(find.textContaining('1 with a problem'), findsOneWidget);
  });

  testWidgets('adding the parsed bulk lines calls addCards and keeps failures',
      (tester) async {
    _useTallSurface(tester);
    final decks = FakeDeckRepository(decks: [_deck('deck-1')]);
    await _pump(tester, decks: decks);

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste FRONT | BACK lines here'),
      'Q1 | A1\nbroken line\nQ2 | A2',
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 cards'));
    await tester.pumpAndSettle();

    expect(decks.calls, contains('addCards(deck-1, 2)'));
    expect(find.text('broken line'), findsOneWidget);
  });

  testWidgets('the footer "View cards" link opens the card list', (tester) async {
    _useTallSurface(tester);
    final rec = _Recorder();
    await _pump(tester,
        decks: FakeDeckRepository(decks: [_deck('deck-1')]), rec: rec);

    await tester.tap(find.text('View cards'));
    await tester.pumpAndSettle();

    expect(rec.location, '/deck/deck-1/cards');
  });

  testWidgets('the footer "Start session" link starts a session for the deck',
      (tester) async {
    _useTallSurface(tester);
    final rec = _Recorder();
    await _pump(tester,
        decks: FakeDeckRepository(decks: [_deck('deck-1')]), rec: rec);

    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle();

    expect(rec.location, '/study/deck-1');
  });
}
