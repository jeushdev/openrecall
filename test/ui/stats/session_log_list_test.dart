import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/domain/history_log.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/stats/session_log_list.dart';

void main() {
  testWidgets('long Feynman metadata reflows below a readable deck title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const deckName = 'Advanced cellular respiration and molecular biology';
    const detail = 'Feynman · 123456 cards';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SessionLogList(
                filter: HistoryFilter.all,
                entries: [
                  HistoryEntry(
                    deckId: 'deck-1',
                    deckName: deckName,
                    courseName: 'Advanced life sciences',
                    accentColor: 'green',
                    studyMode: StudyMode.feynman,
                    cardsReviewed: 123456,
                    completedAt: DateTime(2026, 9, 7),
                    masteryDelta: 987,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text(detail)).dy,
      greaterThan(tester.getTopLeft(find.text(deckName)).dy),
    );
    for (final label in [deckName, detail, '+987%']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
  });

  testWidgets('By Deck keeps mode and delta readable with absent card count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SessionLogList(
                filter: HistoryFilter.byDeck,
                entries: [
                  HistoryEntry(
                    deckId: 'deck-1',
                    deckName: 'An unusually long deck name for history',
                    courseName: 'A long course name for grouped history',
                    accentColor: 'green',
                    studyMode: StudyMode.feynman,
                    cardsReviewed: null,
                    completedAt: DateTime(2026, 9, 7),
                    masteryDelta: -12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Feynman'), findsOneWidget);
    expect(find.text('-12%'), findsOneWidget);
  });
}
