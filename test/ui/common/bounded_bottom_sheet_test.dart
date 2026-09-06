import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/bounded_bottom_sheet.dart';

const _viewports = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(393, 873),
  Size(412, 915),
  Size(480, 960),
];

const _textScales = <double>[1, 1.3, 1.5, 2];

void _configureView(
  WidgetTester tester, {
  required Size viewport,
  double keyboardInset = 0,
}) {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

Widget _host({
  required double textScale,
  required Widget sheetChild,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
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
  );
}

void main() {
  for (final viewport in _viewports) {
    for (final textScale in _textScales) {
      testWidgets(
        'keeps overflowing actions reachable at '
        '${viewport.width.toInt()}x${viewport.height.toInt()} and $textScale',
        (tester) async {
          const keyboardInset = 240.0;
          _configureView(
            tester,
            viewport: viewport,
            keyboardInset: keyboardInset,
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
    _configureView(tester, viewport: const Size(412, 915));
    await tester.pumpWidget(
      _host(textScale: 1, sheetChild: const Text('Short sheet')),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(160));
    expect(find.text('Short sheet'), findsOneWidget);
  });

  testWidgets('uses the active dark theme inside the modal', (tester) async {
    _configureView(tester, viewport: const Size(393, 873));
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
