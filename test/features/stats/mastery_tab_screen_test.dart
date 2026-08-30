import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/troublemaker_card.dart';
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
    );

TroublemakerCard _troublemaker(String id, String deckId, int failCount) =>
    TroublemakerCard(
      id: id,
      deckId: deckId,
      front: 'front $id',
      back: 'back $id',
      failCount: failCount,
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
  testWidgets('renders all four sections from the real aggregation providers',
      (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: [
        _deck(id: 'd1', name: 'Anatomy', masteryLevelSum: 8, totalCards: 4),
        _deck(id: 'd2', name: 'Biochem', masteryLevelSum: 0, totalCards: 4),
      ]),
      courses: FakeCourseRepository(courses: [
        fakeCourse(id: 'c1', name: 'Medicine', accentColor: 'green'),
      ]),
      stats: FakeStatsRepository(
        troublemakers: [
          _troublemaker('a', 'd1', 7),
          _troublemaker('b', 'd2', 3),
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
    expect(find.text('25% · 2 decks'), findsOneWidget);

    // Deck completions — most cleared first, with count badges.
    expect(find.text('Deck completions'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);

    // Troublemakers — excerpt, deck name + miss count, severity badge.
    expect(find.text('Troublemaker cards'), findsOneWidget);
    expect(find.text('front a'), findsOneWidget);
    expect(find.text('Anatomy · missed 7 times'), findsOneWidget);
    expect(find.text('High'), findsOneWidget); // fail_count 7 >= 5
    expect(find.text('Watch'), findsOneWidget); // fail_count 3
  });

  testWidgets('shows non-discouraging empty states when there is no data',
      (tester) async {
    await _pump(
      tester,
      decks: FakeDeckRepository(decks: []),
      courses: FakeCourseRepository(courses: []),
      stats: FakeStatsRepository(troublemakers: [], runThroughs: {}),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.byType(CourseRollupStrip), findsOneWidget); // renders empty
    expect(
      find.textContaining('No decks fully cleared yet'),
      findsOneWidget,
    );
    expect(
      find.textContaining("Nothing's giving you much trouble"),
      findsOneWidget,
    );
  });
}
