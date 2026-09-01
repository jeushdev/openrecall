import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/stats/presentation/mastery_tab_screen.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/mastery/course_rollup_strip.dart';
import 'package:open_recall/ui/mastery/overall_mastery_card.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck({
  required String id,
  required String name,
  String courseId = 'c1',
  int totalCards = 4,
  int masteryLevelSum = 8,
  DateTime? createdAt,
}) =>
    DeckSummary(
      id: id,
      name: name,
      lastStudiedAt: null,
      totalCards: totalCards,
      dueCards: totalCards,
      masteryPercent: 0,
      courseId: courseId,
      masteryLevelSum: masteryLevelSum,
      createdAt: createdAt,
    );

Future<void> _pump(
  WidgetTester tester, {
  required FakeDeckRepository decks,
  required FakeCourseRepository courses,
  required FakeStatsRepository stats,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deckRepositoryProvider.overrideWithValue(decks),
        courseRepositoryProvider.overrideWithValue(courses),
        statsRepositoryProvider.overrideWithValue(stats),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MasteryTabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every section, ending with the recent-activity feed',
      (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: [
        _deck(
          id: 'd1',
          name: 'Anatomy',
          masteryLevelSum: 8,
          totalCards: 4,
          createdAt: DateTime(2026, 8, 1),
        ),
        _deck(id: 'd2', name: 'Biochem', masteryLevelSum: 0, totalCards: 4),
      ]),
      courses: FakeCourseRepository(courses: [
        fakeCourse(id: 'c1', name: 'Medicine', accentColor: 'green'),
      ]),
      stats: FakeStatsRepository(
        recentCompletedSessions: [
          CompletedSessionActivity(
            deckId: 'd1',
            completedAt: DateTime(2026, 8, 25),
            masteryDelta: 7,
          ),
        ],
        runThroughs: {'d1': 3, 'd2': 1},
      ),
    );

    // Overall: (8 + 0) / ((4 + 4) * 4) * 100 = 25.
    expect(find.byType(OverallMasteryCard), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // Course rollup chip.
    expect(find.byType(CourseRollupStrip), findsOneWidget);
    expect(find.text('Medicine'), findsOneWidget);

    // Deck completions — still present.
    expect(find.text('Deck completions'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);

    // Recent activity — the new final section.
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Completed Anatomy'), findsOneWidget);
    expect(find.text('+7%'), findsOneWidget);
    expect(find.text('Created deck Anatomy'), findsOneWidget);

    // Troublemakers are gone.
    expect(find.text('Troublemaker cards'), findsNothing);
  });

  testWidgets('shows non-discouraging empty states when there is no data',
      (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: []),
      courses: FakeCourseRepository(courses: []),
      stats: FakeStatsRepository(recentCompletedSessions: [], runThroughs: {}),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.byType(CourseRollupStrip), findsOneWidget); // renders empty
    expect(
      find.textContaining('No decks fully cleared yet'),
      findsOneWidget,
    );
    expect(
      find.text('Your recent study activity will show up here.'),
      findsOneWidget,
    );
  });
}
