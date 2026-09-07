import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';
import 'package:open_recall/features/study/presentation/widgets/rating_row.dart';
import 'package:open_recall/theme/app_theme.dart';

Future<void> _pumpRow(
  WidgetTester tester, {
  required bool enabled,
  ValueChanged<FlipRating>? onRate,
  Size size = const Size(800, 600),
  double textScale = 1,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RatingRow(enabled: enabled, onRate: onRate ?? (_) {}),
            ),
          ),
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

    testWidgets('buttons use at least the 60px hit target', (tester) async {
      await _pumpRow(tester, enabled: true);

      for (final label in FlipRating.values.map((r) => r.label)) {
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(size.height, greaterThanOrEqualTo(60));
      }
    });

    testWidgets('keeps every label complete across the responsive matrix', (
      tester,
    ) async {
      const sizes = [
        Size(320, 568),
        Size(360, 640),
        Size(360, 800),
        Size(393, 873),
        Size(412, 915),
        Size(480, 960),
      ];
      const scales = [1.0, 1.3, 1.5, 2.0];

      for (final size in sizes) {
        for (final scale in scales) {
          await _pumpRow(tester, enabled: true, size: size, textScale: scale);
          expect(tester.takeException(), isNull, reason: '$size at $scale');
          for (final rating in FlipRating.values) {
            final text = tester.widget<Text>(find.text(rating.label));
            expect(text.maxLines, isNull);
            expect(text.overflow, isNot(TextOverflow.ellipsis));
            final textRect = tester.getRect(find.text(rating.label));
            final buttonRect = tester.getRect(
              find.ancestor(
                of: find.text(rating.label),
                matching: find.byType(InkWell),
              ),
            );
            expect(buttonRect.contains(textRect.topLeft), isTrue);
            expect(buttonRect.contains(textRect.bottomRight), isTrue);
          }
        }
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
