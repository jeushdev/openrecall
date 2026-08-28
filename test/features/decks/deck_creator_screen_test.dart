import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/ai_prompt.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/presentation/deck_creator_screen.dart';

import '../../support/fake_deck_repository.dart';

Widget _host(FakeDeckRepository fake, {String deckId = 'deck-1'}) => ProviderScope(
      overrides: [deckRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: DeckCreatorScreen(deckId: deckId, deckName: 'Biology'),
      ),
    );

/// Gives the test a viewport tall enough to hold the whole Deck Creator
/// (card list + add form + expanded bulk panel) without scrolling, so taps on
/// the bulk-panel buttons land.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

FlashCard _card({
  String id = 'card-1',
  String front = 'Capital of France',
  String back = 'Paris',
  String? keyword,
}) =>
    FlashCard(
      id: id,
      deckId: 'deck-1',
      front: front,
      back: back,
      keyword: keyword,
      masteryLevel: 0,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  testWidgets('shows the empty state when the deck has no cards',
      (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add your first card'), findsOneWidget);
  });

  testWidgets('lists existing cards with their keyword', (tester) async {
    await tester.pumpWidget(_host(
      FakeDeckRepository(cards: [_card(keyword: 'Paris')]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Capital of France'), findsOneWidget);
    expect(find.text('Paris'), findsWidgets);
  });

  testWidgets('the add-card form calls addCard with the entered fields',
      (tester) async {
    final fake = FakeDeckRepository();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Front'), 'Capital of France');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Back'), 'Paris');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Keyword (optional)'), 'Paris');
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();

    expect(
      fake.calls,
      contains(
          'addCard(deck=deck-1, front=Capital of France, back=Paris, keyword=Paris)'),
    );
  });

  testWidgets('a keyword absent from front and back blocks the add',
      (tester) async {
    final fake = FakeDeckRepository();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Front'), 'Capital of France');
    await tester.enterText(find.widgetWithText(TextFormField, 'Back'), 'Paris');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Keyword (optional)'), 'Berlin');
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must appear in the front or back'),
        findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('addCard')), isEmpty);
  });

  testWidgets('the bulk-paste preview updates after the debounce',
      (tester) async {
    await tester.pumpWidget(_host(FakeDeckRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulk paste'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Paste FRONT | BACK lines here'),
      'Capital of France | {{Paris}}\nbroken line',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('1 ready'), findsOneWidget);
    expect(find.textContaining('1 with a problem'), findsOneWidget);
  });

  testWidgets('adding the parsed lines calls addCards and keeps failures',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeDeckRepository();
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulk paste'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Paste FRONT | BACK lines here'),
      'Q1 | A1\nbroken line\nQ2 | A2',
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(FilledButton, 'Add 2 cards'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('addCards(deck-1, 2)'));
    expect(find.text('broken line'), findsOneWidget);
  });

  testWidgets('Copy AI Prompt puts the prompt on the clipboard', (tester) async {
    _useTallSurface(tester);
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(FakeDeckRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulk paste'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copy AI Prompt'));
    await tester.pumpAndSettle();

    expect(clipboardText, aiIngestionPrompt);
  });

  testWidgets('deleting a card confirms then calls deleteCard', (tester) async {
    final fake = FakeDeckRepository(cards: [_card()]);
    await tester.pumpWidget(_host(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('deleteCard(card-1)'));
  });
}
