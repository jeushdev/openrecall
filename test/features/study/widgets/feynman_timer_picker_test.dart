import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/presentation/widgets/feynman_timer_picker.dart';
import 'package:open_recall/theme/app_theme.dart';

void main() {
  testWidgets('all presets remain reachable across the responsive matrix', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        int? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SafeArea(
                    child: FeynmanTimerPicker(
                      onSelected: (value) => selected = value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: '$size at $scale');
        final last = find.text('120s');
        await tester.scrollUntilVisible(
          last,
          100,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('pre-session-picker-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(last.hitTestable(), findsOneWidget);
        await tester.tap(last);
        expect(selected, 120);
        expect(find.text('default'), findsOneWidget);
      }
    }
  });
}
