import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/card_list_screen.dart';
import 'package:open_recall/features/decks/presentation/widgets/card_list_item.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_deck_repository.dart';

DeckSummary _deck(String id, {String name = 'Cell structure', int cards = 0}) =>
    DeckSummary(
      id: id,
      name: name,
      courseId: null,
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
}) =>
    FlashCard(
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

Future<void> _pump(
  WidgetTester tester,
  _Recorder rec, {
  required FakeDeckRepository decks,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: AppRoutes.cardListPath,
        name: AppRoutes.cardListName,
        builder: (_, state) =>
            CardListScreen(deckId: state.pathParameters['deckId']!),
      ),
      GoRoute(
        path: AppRoutes.importCardsPath,
        name: AppRoutes.importCardsName,
        builder: (_, state) {
          rec.location = state.uri.toString();
          return const Scaffold(body: Text('import stub'));
        },
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [deckRepositoryProvider.overrideWithValue(decks)],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  router.push('/deck/deck-1/cards');
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byType(CardListItem).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the deck name in the app bar', (tester) async {
    await _pump(
      tester,
      _Recorder(),
      decks: FakeDeckRepository(
        decks: [_deck('deck-1', name: 'Cell structure')],
        cards: [_card()],
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

  testWidgets('renders one row per card with a front/back/keyword preview',
      (tester) async {
    await _pump(
      tester,
      _Recorder(),
      decks: FakeDeckRepository(
        decks: [_deck('deck-1')],
        cards: [
          _card(front: 'Capital of France', back: 'Paris', keywords: ['Paris']),
          _card(id: 'card-2', front: 'Largest planet', back: 'Jupiter'),
        ],
      ),
    );

    expect(find.byType(CardListItem), findsNWidgets(2));
    expect(find.text('Capital of France'), findsOneWidget);
    expect(find.text('Jupiter'), findsOneWidget);
    // 'Paris' shows twice for card 1: the back preview and the keyword pill.
    expect(find.text('Paris'), findsNWidgets(2));
  });

  testWidgets('an empty deck offers an Add cards CTA into import',
      (tester) async {
    final rec = _Recorder();
    await _pump(tester, rec, decks: FakeDeckRepository(decks: [_deck('deck-1')]));

    expect(find.text('No cards yet.'), findsOneWidget);

    await tester.tap(find.text('Add cards'));
    await tester.pumpAndSettle();

    expect(rec.location, '/deck/deck-1/import');
  });

  testWidgets('tapping a row opens the card editor', (tester) async {
    await _pump(
      tester,
      _Recorder(),
      decks: FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]),
    );

    await _openEditor(tester);

    expect(find.text('Edit card'), findsOneWidget);
  });

  testWidgets('editing fields and saving calls updateCard, then closes',
      (tester) async {
    final decks =
        FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]);
    await _pump(tester, _Recorder(), decks: decks);

    await _openEditor(tester);
    await tester.enterText(find.byType(TextFormField).first, 'New front');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('updateCard(id=card-1, front=New front, back=Paris, '
          'keywords=[], concept=false)'),
    );
    expect(find.text('Edit card'), findsNothing);
  });

  testWidgets('a keyword absent from the front and back is rejected',
      (tester) async {
    final decks =
        FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]);
    await _pump(tester, _Recorder(), decks: decks);

    await _openEditor(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a keyword'),
      'notonthecard',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The chip was not added; an inline error explains why.
    expect(find.text('Keyword must appear in the front or back text.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      decks.calls,
      contains('updateCard(id=card-1, front=Capital of France, back=Paris, '
          'keywords=[], concept=false)'),
    );
  });

  testWidgets('Delete in the editor confirms, calls deleteCard, then closes',
      (tester) async {
    final decks =
        FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]);
    await _pump(tester, _Recorder(), decks: decks);

    await _openEditor(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete card?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(decks.calls, contains('deleteCard(card-1)'));
    expect(find.text('Edit card'), findsNothing);
  });

  testWidgets('Delete can be cancelled', (tester) async {
    final decks =
        FakeDeckRepository(decks: [_deck('deck-1')], cards: [_card()]);
    await _pump(tester, _Recorder(), decks: decks);

    await _openEditor(tester);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(decks.calls.where((c) => c.startsWith('deleteCard')), isEmpty);
    expect(find.text('Edit card'), findsOneWidget);
  });
}
