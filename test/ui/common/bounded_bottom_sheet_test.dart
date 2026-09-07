import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/bounded_bottom_sheet.dart';

import '../../support/responsive_test_harness.dart';

Widget _host({
  required double textScale,
  required Widget sheetChild,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: withTextScale(
      textScale: textScale,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => BoundedBottomSheetBody(
                  padding: const EdgeInsets.all(20),
                  child: sheetChild,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final viewport in responsiveViewports) {
    for (final textScale in responsiveTextScales) {
      testWidgets(
        'keeps overflowing actions reachable at '
        '${viewport.width.toInt()}x${viewport.height.toInt()} and $textScale',
        (tester) async {
          const keyboardInset = 240.0;
          configureResponsiveView(
            tester,
            viewport: viewport,
            viewInsets: const EdgeInsets.only(bottom: keyboardInset),
          );
          var tapped = false;
          await tester.pumpWidget(
            _host(
              textScale: textScale,
              sheetChild: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Keyboard-aware sheet'),
                  for (var index = 0; index < 12; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('A long, wrapping sheet row number $index'),
                    ),
                  FilledButton(
                    key: const ValueKey('final-sheet-action'),
                    onPressed: () => tapped = true,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final action = find.byKey(const ValueKey('final-sheet-action'));
          await tester.scrollUntilVisible(
            action,
            250,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('bounded-bottom-sheet-scroll')),
              matching: find.byType(Scrollable),
            ),
          );
          expect(action.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(action).dy,
            lessThanOrEqualTo(viewport.height - keyboardInset),
          );
          await tester.tap(action);
          expect(tapped, isTrue);
        },
      );
    }
  }

  testWidgets('a short sheet retains its natural height', (tester) async {
    configureResponsiveView(tester, viewport: const Size(412, 915));
    await tester.pumpWidget(
      _host(textScale: 1, sheetChild: const Text('Short sheet')),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(160));
    expect(find.text('Short sheet'), findsOneWidget);
  });

  testWidgets('uses the active dark theme inside the modal', (tester) async {
    configureResponsiveView(tester, viewport: const Size(393, 873));
    await tester.pumpWidget(
      _host(
        textScale: 1.5,
        theme: AppTheme.dark,
        sheetChild: const Text('Dark sheet'),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheetContext = tester.element(find.text('Dark sheet'));
    expect(Theme.of(sheetContext).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
