import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/presentation/widgets/rating_bar.dart';

void main() {
  Widget host({required bool enabled, ValueChanged<FlipRating>? onRate}) =>
      MaterialApp(
        home: Scaffold(
          body: RatingBar(enabled: enabled, onRate: onRate ?? (_) {}),
        ),
      );

  testWidgets('shows a button for every rating, Unfamiliar..Mastered',
      (tester) async {
    await tester.pumpWidget(host(enabled: true));
    for (final rating in FlipRating.values) {
      expect(find.widgetWithText(FilledButton, rating.label), findsOneWidget);
    }
  });

  testWidgets('a tap fires onRate with the matching rating', (tester) async {
    FlipRating? tapped;
    await tester.pumpWidget(host(enabled: true, onRate: (r) => tapped = r));

    await tester.tap(find.widgetWithText(FilledButton, 'Okay'));
    expect(tapped, FlipRating.okay);
  });

  testWidgets('every button is disabled until the card is flipped',
      (tester) async {
    await tester.pumpWidget(host(enabled: false));
    for (final rating in FlipRating.values) {
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, rating.label),
      );
      expect(button.onPressed, isNull);
    }
  });
}
