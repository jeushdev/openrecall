import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/presentation/widgets/flip_card.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

FlashCard _card({
  String id = 'a',
  String front = 'the prompt',
  String back = 'the answer',
}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: const [],
  isConcept: false,
  masteryLevel: 0,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  // Both transition styles must land on the back face after a tap + settle.
  for (final transition in const ['flip3d', 'fade']) {
    testWidgets('the $transition transition reveals the back on tap', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'card_transition': transition});

      bool? flipped;
      await tester.pumpWidget(
        _host(FlipCard(card: _card(), onFlippedChanged: (f) => flipped = f)),
      );
      await tester.pumpAndSettle();

      expect(find.text('the prompt'), findsOneWidget);
      expect(find.text('the answer'), findsNothing);

      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();

      expect(flipped, isTrue);
      expect(find.text('the answer'), findsOneWidget);
      // The faces are swapped, not stacked — the front is gone once settled.
      expect(find.text('the prompt'), findsNothing);
    });
  }

  testWidgets('a card change resets a flipped card to the front', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    late StateSetter setter;
    var card = _card();

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            setter = setState;
            return FlipCard(card: card, onFlippedChanged: (_) {});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();
    expect(find.text('the answer'), findsOneWidget);

    setter(() => card = _card(id: 'b', back: 'other answer'));
    await tester.pumpAndSettle();

    expect(find.text('the prompt'), findsOneWidget);
    expect(find.text('other answer'), findsNothing);
  });
}
