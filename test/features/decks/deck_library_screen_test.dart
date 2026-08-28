import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/presentation/deck_creator_screen.dart';
import 'package:open_recall/features/decks/presentation/deck_library_screen.dart';

import '../../support/fake_deck_repository.dart';
import '../../support/pump_app.dart';

DeckSummary _summary({
  String id = 'deck-1',
  String name = 'Biology',
  int total = 3,
  int due = 3,
  int mastery = 0,
}) =>
    DeckSummary(
      id: id,
      name: name,
      lastStudiedAt: null,
      totalCards: total,
      dueCards: due,
      masteryPercent: mastery,
    );

void main() {
  testWidgets('with no decks it shows the create-first-deck empty state',
      (tester) async {
    await pumpApp(tester, signedIn: true);

    expect(find.byType(DeckLibraryScreen), findsOneWidget);
    expect(find.textContaining('No decks yet'), findsOneWidget);
  });

  testWidgets('renders a tile per deck with its name and due/total count',
      (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      decks: FakeDeckRepository(decks: [
        _summary(name: 'Biology', total: 5, due: 2),
        _summary(id: 'deck-2', name: 'History', total: 10, due: 10),
      ]),
    );

    expect(find.text('Biology'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('2/5'), findsOneWidget);
    expect(find.textContaining('10/10'), findsOneWidget);
  });

  testWidgets('the Create deck button opens a name dialog', (tester) async {
    await pumpApp(tester, signedIn: true);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Create deck'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Deck name'), findsOneWidget);
  });

  testWidgets('creating a deck calls the repository and opens the Deck Creator',
      (tester) async {
    final refs = await pumpApp(tester, signedIn: true);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Create deck'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chemistry');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(refs.decks.calls, contains('createDeck(Chemistry)'));
    expect(find.byType(DeckCreatorScreen), findsOneWidget);
  });

  testWidgets('tapping a deck opens the Deck Creator for it', (tester) async {
    await pumpApp(
      tester,
      signedIn: true,
      decks: FakeDeckRepository(decks: [_summary(name: 'Biology')]),
    );

    await tester.tap(find.text('Biology'));
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsOneWidget);
  });
}
