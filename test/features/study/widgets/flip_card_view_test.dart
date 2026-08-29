import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/presentation/widgets/flip_card_view.dart';

FlashCard _card(String id) => FlashCard(
      id: id,
      deckId: 'deck-1',
      front: 'front-$id',
      back: 'back-$id',
      keyword: null,
      masteryLevel: 0,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  testWidgets('starts on the front and flips to the back on tap', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FlipCardView(card: _card('a'))),
    ));

    expect(find.text('front-a'), findsOneWidget);
    expect(find.text('back-a'), findsNothing);

    await tester.tap(find.byType(FlipCardView));
    await tester.pump();

    expect(find.text('back-a'), findsOneWidget);
  });

  testWidgets('reports its flipped state to the parent', (tester) async {
    final flips = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlipCardView(card: _card('a'), onFlippedChanged: flips.add),
      ),
    ));

    await tester.tap(find.byType(FlipCardView));
    await tester.pump();

    expect(flips, contains(true));
  });

  testWidgets('resets to the front when the card changes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FlipCardView(card: _card('a'), key: const Key('v'))),
    ));
    await tester.tap(find.byType(FlipCardView));
    await tester.pump();
    expect(find.text('back-a'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FlipCardView(card: _card('b'), key: const Key('v'))),
    ));
    await tester.pump();

    expect(find.text('front-b'), findsOneWidget);
    expect(find.text('back-b'), findsNothing);
  });
}
