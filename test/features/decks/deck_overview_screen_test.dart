import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/deck_creator_screen.dart';
import 'package:open_recall/features/decks/presentation/deck_overview_screen.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/pump_app.dart';

FlashCard _card({
  String id = 'card-1',
  String front = 'Capital of France',
  String back = 'Paris',
  String? keyword,
  int mastery = 0,
  int fails = 0,
}) =>
    FlashCard(
      id: id,
      deckId: 'deck-1',
      front: front,
      back: back,
      keyword: keyword,
      masteryLevel: mastery,
      failCount: fails,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Widget _host(FakeDeckRepository fake) => ProviderScope(
      overrides: [deckRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(
        home: DeckOverviewScreen(deckId: 'deck-1', deckName: 'Biology'),
      ),
    );

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, label),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('empty deck shows the no-cards prompt, not the stats', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('no cards yet'), findsOneWidget);
    expect(find.text('Study modes'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Add cards'), findsOneWidget);
  });

  testWidgets('renders deck stats from real card data', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [
      _card(id: 'a', keyword: 'Paris', mastery: 4),
      _card(id: 'b', back: 'one\ntwo'),
      _card(id: 'c'),
    ])));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 cards'), findsOneWidget);
    expect(find.textContaining('2 due'), findsOneWidget);
    expect(find.textContaining('1 with a keyword'), findsOneWidget);
    expect(find.textContaining('1 multi-line'), findsOneWidget);
  });

  testWidgets('Flip is always enabled; Cloze/List/Feynman gate on card content',
      (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Flip & Rate'), isTrue);
    expect(_enabled(tester, 'Cloze Type-in'), isFalse);
    expect(_enabled(tester, 'List Unmask'), isFalse);
    expect(_enabled(tester, 'Feynman Synthesis'), isFalse);
    expect(find.text('No cards support this yet'), findsNWidgets(3));
  });

  testWidgets('a keyword card enables Cloze', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [
      _card(keyword: 'Paris'),
    ])));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Cloze Type-in'), isTrue);
    expect(_enabled(tester, 'List Unmask'), isFalse);
  });

  testWidgets('a multi-line card enables List and Feynman', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [
      _card(back: 'point one\npoint two'),
    ])));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'List Unmask'), isTrue);
    expect(_enabled(tester, 'Feynman Synthesis'), isTrue);
    expect(_enabled(tester, 'Cloze Type-in'), isFalse);
  });

  testWidgets('tapping an enabled mode button shows a placeholder SnackBar',
      (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Flip & Rate'));
    await tester.pump();

    expect(find.textContaining('arrive in the next update'), findsOneWidget);
  });

  testWidgets('the capped toggle reveals the fixed presets', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '10'), findsNothing);

    await tester.tap(find.text('Capped'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, '10'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '20'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '30'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
  });

  testWidgets('all-caught-up banner shows only when nothing is due',
      (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [
      _card(id: 'a', mastery: 4),
      _card(id: 'b', mastery: 4),
    ])));
    await tester.pumpAndSettle();

    expect(find.textContaining('all caught up'), findsOneWidget);
  });

  testWidgets('no caught-up banner while cards are still due', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(find.textContaining('all caught up'), findsNothing);
  });

  testWidgets('troublemaker cards list high-fail cards, hidden otherwise',
      (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [
      _card(id: 'a', front: 'Sticky one', fails: 4),
      _card(id: 'b', front: 'Easy one'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Troublemaker cards'), findsOneWidget);
    expect(find.text('Sticky one'), findsOneWidget);
    expect(find.textContaining('Failed 4 times'), findsOneWidget);
  });

  testWidgets('no troublemaker section when nothing has failed', (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository(cards: [_card()])));
    await tester.pumpAndSettle();

    expect(find.text('Troublemaker cards'), findsNothing);
  });

  testWidgets('"Add cards" opens the Deck Creator for this deck', (tester) async {
    _useTallSurface(tester);
    await pumpApp(
      tester,
      signedIn: true,
      decks: FakeDeckRepository(
        decks: [
          const DeckSummary(
            id: 'deck-1',
            name: 'Biology',
            lastStudiedAt: null,
            totalCards: 1,
            dueCards: 1,
            masteryPercent: 0,
          ),
        ],
        cards: [_card()],
      ),
    );

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckOverviewScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add cards'));
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsOneWidget);
  });
}
