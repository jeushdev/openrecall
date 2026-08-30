import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/presentation/widgets/rating_row.dart';
import 'package:open_recall/theme/app_theme.dart';

Future<void> _pumpRow(
  WidgetTester tester, {
  required bool enabled,
  ValueChanged<FlipRating>? onRate,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: RatingRow(
          enabled: enabled,
          onRate: onRate ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('RatingRow', () {
    testWidgets('renders one button per FlipRating (four)', (tester) async {
      await _pumpRow(tester, enabled: true);

      expect(find.byType(InkWell), findsNWidgets(4));
      for (final rating in FlipRating.values) {
        expect(find.text(rating.label), findsOneWidget);
      }
      expect(find.text('Okay'), findsNothing);
    });

    testWidgets('buttons use the enlarged 60px hit target', (tester) async {
      await _pumpRow(tester, enabled: true);

      for (final label in FlipRating.values.map((r) => r.label)) {
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(size.height, 60);
      }
    });

    testWidgets('a disabled row does not fire onRate', (tester) async {
      FlipRating? rated;
      await _pumpRow(tester, enabled: false, onRate: (r) => rated = r);

      await tester.tap(find.text('Mastered'));
      await tester.pump();

      expect(rated, isNull);
    });

    testWidgets('an enabled row reports the tapped rating', (tester) async {
      FlipRating? rated;
      await _pumpRow(tester, enabled: true, onRate: (r) => rated = r);

      await tester.tap(find.text('Familiar'));
      await tester.pump();

      expect(rated, FlipRating.familiar);
    });
  });
}
