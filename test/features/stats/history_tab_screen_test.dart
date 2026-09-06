import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/stats/presentation/history_tab_screen.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck(String id, {String? courseId, String? name}) => DeckSummary(
  id: id,
  name: name ?? 'Deck $id',
  lastStudiedAt: null,
  totalCards: 6,
  dueCards: 6,
  masteryPercent: 0,
  courseId: courseId,
);

Future<void> _pump(
  WidgetTester tester, {
  required FakeStatsRepository stats,
  List<DeckSummary>? decks,
  FakeCourseRepository? courses,
  Size viewport = const Size(1200, 4000),
  double textScale = 1,
}) async {
  // A tall surface so the whole scroll view (calendar grid + toggle + log)
  // is laid out — the default 600px viewport clips the log off the bottom of
  // the lazily-built list.
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        statsRepositoryProvider.overrideWithValue(stats),
        deckRepositoryProvider.overrideWithValue(
          FakeDeckRepository(decks: decks ?? [_deck('d1', courseId: 'c1')]),
        ),
        courseRepositoryProvider.overrideWithValue(
          courses ??
              FakeCourseRepository(
                courses: [
                  fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green'),
                ],
              ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const HistoryTabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'long session metadata remains reachable at 320x568 and 2x text',
    (tester) async {
      const deckName = 'Advanced cellular respiration and molecular biology';
      final stats = FakeStatsRepository(
        recentCompletedSessions: [
          CompletedSessionActivity(
            deckId: 'd1',
            completedAt: DateTime(2026, 8, 20),
            masteryDelta: 987,
            studyMode: StudyMode.feynman,
            cardsReviewed: 123456,
          ),
        ],
      );
      await _pump(
        tester,
        stats: stats,
        decks: [_deck('d1', courseId: 'c1', name: deckName)],
        viewport: const Size(320, 568),
        textScale: 2,
      );

      final detail = find.text('Feynman · 123456 cards');
      await tester.ensureVisible(detail);
      await tester.pumpAndSettle();
      expect(detail.hitTestable(), findsOneWidget);
      expect(find.text('+987%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders the heatmap month label and the toggle', (tester) async {
    await _pump(tester, stats: FakeStatsRepository());

    expect(find.text('History'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('By Deck'), findsOneWidget);
    // Weekday header row of the calendar heatmap.
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('shows an empty-state line when there are no sessions', (
    tester,
  ) async {
    await _pump(tester, stats: FakeStatsRepository());

    expect(
      find.text('Your completed study sessions will show up here.'),
      findsOneWidget,
    );
  });

  testWidgets('renders a session row and switches to By Deck grouping', (
    tester,
  ) async {
    final stats = FakeStatsRepository(
      recentCompletedSessions: [
        CompletedSessionActivity(
          deckId: 'd1',
          completedAt: DateTime(2026, 8, 20),
          masteryDelta: 7,
          studyMode: StudyMode.cloze,
          cardsReviewed: 9,
        ),
      ],
      completedSessions: [
        CompletedSession(
          startedAt: DateTime(2026, 8, 20, 9),
          completedAt: DateTime(2026, 8, 20, 9, 20),
          cardsReviewed: 9,
        ),
      ],
    );
    await _pump(tester, stats: stats);

    expect(find.text('Deck d1'), findsOneWidget);
    expect(find.text('Cloze · 9 cards'), findsOneWidget);
    expect(find.text('+7%'), findsOneWidget);

    await tester.tap(find.text('By Deck'));
    await tester.pumpAndSettle();

    // The grouped-inset section header (uppercased) now carries the course ·
    // deck label; the row drops its name.
    expect(find.text('BIOLOGY · DECK D1'), findsOneWidget);
    expect(find.text('Deck d1'), findsNothing);
  });
}
