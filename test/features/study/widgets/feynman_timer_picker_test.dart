import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/presentation/widgets/feynman_timer_picker.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../../support/responsive_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('all presets remain reachable across the responsive matrix', (
    tester,
  ) async {
    for (final size in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        configureResponsiveView(tester, viewport: size);
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
