import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/presentation/widgets/mode_picker.dart';
import 'package:open_recall/theme/app_theme.dart';

void main() {
  testWidgets('all modes remain reachable across the responsive matrix', (
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
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
