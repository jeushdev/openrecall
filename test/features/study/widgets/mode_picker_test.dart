import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/presentation/widgets/mode_picker.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../../support/responsive_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('all modes remain reachable across the responsive matrix', (
    tester,
  ) async {
    for (final size in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        configureResponsiveView(tester, viewport: size);
        StudyMode? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SizedBox(
                    height: 320,
                    child: ModePicker(
                      modes: StudyMode.values,
                      onSelected: (value) => selected = value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull, reason: '$size at $scale');
        final last = find.text(StudyMode.feynman.label);
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
        expect(selected, StudyMode.feynman);
      }
    }
  });

  testWidgets('renders the narrow enlarged layout in dark theme', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                height: 320,
                child: ModePicker(modes: StudyMode.values, onSelected: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('How do you want to study this deck?'), findsOneWidget);
  });
}
