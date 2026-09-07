import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/settings/settings_segmented_control.dart';

import '../../support/responsive_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('grows to contain wrapped labels at enlarged text scale', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: SettingsSegmentedControl<int>(
                value: 0,
                onChanged: (_) {},
                options: const [
                  (value: 0, label: '3D flip'),
                  (value: 1, label: 'Fade & slide'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final controlRect = tester.getRect(
      find.byType(SettingsSegmentedControl<int>),
    );
    final labelRect = tester.getRect(find.text('Fade & slide'));
    expect(controlRect.height, greaterThan(40));
    expect(controlRect.contains(labelRect.topLeft), isTrue);
    expect(controlRect.contains(labelRect.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('labels stay contained and selectable across the matrix', (
    tester,
  ) async {
    for (final viewport in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        configureResponsiveView(tester, viewport: viewport);
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(32),
                  child: SettingsSegmentedControl<int>(
                    value: 0,
                    onChanged: (value) => selected = value,
                    options: const [
                      (value: 0, label: '3D flip'),
                      (value: 1, label: 'Fade & slide'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: '$viewport at ${scale}x',
        );
        final control = tester.getRect(
          find.byType(SettingsSegmentedControl<int>),
        );
        for (final label in ['3D flip', 'Fade & slide']) {
          final labelRect = tester.getRect(find.text(label));
          expect(control.contains(labelRect.topLeft), isTrue);
          expect(control.contains(labelRect.bottomRight), isTrue);
        }
        await tester.tap(find.text('Fade & slide'));
        expect(selected, 1);
      }
    }
  });
}
