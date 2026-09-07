import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/session_outcome.dart';
import 'package:open_recall/features/study/presentation/widgets/session_summary_view.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../../support/responsive_test_harness.dart';

const _outcome = SessionOutcome(
  masteryPercentBefore: 17,
  masteryPercentAfter: 83,
  cardsStudied: 123456,
  mastered: 98765,
  parked: 24680,
  firstTryMastered: 54321,
  requeues: 13579,
);

Widget _host({
  required StudyMode mode,
  required double textScale,
  bool dark = false,
  bool hasParked = true,
  VoidCallback? onDrill,
  VoidCallback? onDone,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    home: withTextScale(
      textScale: textScale,
      child: SessionSummaryView(
        mode: mode,
        deckName: 'A deliberately long cellular biology deck name for responsive testing',
        outcome: _outcome,
        hasParked: hasParked,
        onDrillParked: onDrill ?? () {},
        onDone: onDone ?? () {},
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  final screenCases = <({Size size, double scale})>[
    for (final size in responsiveViewports) (size: size, scale: 1),
    (size: const Size(320, 568), scale: 2),
    (size: const Size(360, 640), scale: 2),
    (size: const Size(412, 915), scale: 2),
  ];

  for (final testCase in screenCases) {
    testWidgets('summary actions remain reachable at '
        '${testCase.size.width.toInt()}x${testCase.size.height.toInt()} '
        'and ${testCase.scale}x text', (tester) async {
      configureResponsiveView(tester, viewport: testCase.size);
      var drilled = false;
      var done = false;
      await tester.pumpWidget(
        _host(
          mode: StudyMode.feynman,
          textScale: testCase.scale,
          dark: testCase.size == const Size(412, 915),
          onDrill: () => drilled = true,
          onDone: () => done = true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      final deckName = find.text(
        'A DELIBERATELY LONG CELLULAR BIOLOGY DECK NAME FOR RESPONSIVE TESTING',
      );
      expectTextIsComplete(tester, deckName);

      final drill = find.widgetWithText(FilledButton, 'Drill parked cards now');
      await tester.scrollUntilVisible(
        drill,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(drill.hitTestable(), findsOneWidget);
      expectTextIsComplete(tester, find.text('Drill parked cards now'));
      await tester.tap(drill);
      expect(drilled, isTrue);

      final doneButton = find.widgetWithText(TextButton, 'Done');
      await tester.ensureVisible(doneButton);
      await tester.pump();
      expect(doneButton.hitTestable(), findsOneWidget);
      await tester.tap(doneButton);
      expect(done, isTrue);
    });
  }

  for (final entry in const {
    StudyMode.flip: 'Recalled on the first flip',
    StudyMode.cloze: 'Typed right on the first try',
    StudyMode.feynman: 'Recalled on the first pass',
  }.entries) {
    testWidgets('${entry.key.name} uses its complete summary metric label', (
      tester,
    ) async {
      configureResponsiveView(tester, viewport: const Size(320, 568));
      await tester.pumpWidget(
        _host(mode: entry.key, textScale: 2, hasParked: false),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final label = find.text(entry.value);
      await tester.scrollUntilVisible(
        label,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expectTextIsComplete(tester, label);
      expect(find.text('Drill parked cards now'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('summary remains stable during its progress animation', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(393, 873));
    await tester.pumpWidget(_host(mode: StudyMode.flip, textScale: 1));

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('83%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
