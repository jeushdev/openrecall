import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/activity_feed.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck({
  required String id,
  String? courseId,
  required int totalCards,
  required int masteryLevelSum,
  DateTime? createdAt,
}) =>
    DeckSummary(
      id: id,
      name: id,
      lastStudiedAt: null,
      totalCards: totalCards,
      dueCards: totalCards,
      masteryPercent: 0,
      courseId: courseId,
      masteryLevelSum: masteryLevelSum,
      createdAt: createdAt,
    );

void main() {
  late FakeDeckRepository decks;
  late FakeCourseRepository courses;
  late FakeStatsRepository stats;
  late ProviderContainer container;

  ProviderContainer build() => ProviderContainer(
        overrides: [
          deckRepositoryProvider.overrideWithValue(decks),
          courseRepositoryProvider.overrideWithValue(courses),
          statsRepositoryProvider.overrideWithValue(stats),
        ],
      );

  setUp(() {
    decks = FakeDeckRepository(decks: [
      _deck(
        id: 'd1',
        courseId: 'c1',
        totalCards: 2,
        masteryLevelSum: 8,
        createdAt: DateTime(2026, 8, 1),
      ),
      _deck(id: 'd2', courseId: 'c1', totalCards: 10, masteryLevelSum: 0),
      _deck(id: 'd3', courseId: 'c2', totalCards: 4, masteryLevelSum: 8),
    ]);
    courses = FakeCourseRepository(courses: [
      fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green'),
      fakeCourse(id: 'c2', name: 'History'),
    ]);
    stats = FakeStatsRepository(
      recentCompletedSessions: [
        CompletedSessionActivity(
          deckId: 'd1',
          completedAt: DateTime(2026, 8, 20),
          masteryDelta: 9,
        ),
      ],
      runThroughs: {'d1': 3, 'd3': 1},
    );
    container = build();
    addTearDown(container.dispose);
  });

  test('overallMasteryProvider is the card-weighted % across every deck', () async {
    // (8 + 0 + 8) / ((2 + 10 + 4) * 4) * 100 = 16 / 64 * 100 = 25
    expect(await container.read(overallMasteryProvider.future), 25);
  });

  test('overallMasteryProvider resolves with appDatabaseProvider null', () async {
    // No override of appDatabaseProvider — it is null by default, so the whole
    // chain runs against in-memory fakes with no SQLite mirror.
    expect(
      container.read(overallMasteryProvider),
      isA<AsyncValue<int>>(),
    );
    await container.read(overallMasteryProvider.future);
  });

  test('courseSummariesProvider rolls decks up under their course', () async {
    final summaries = await container.read(courseSummariesProvider.future);

    expect(summaries.map((s) => s.name), ['Biology', 'History']);
    expect(summaries.first.deckCount, 2);
    expect(summaries.first.totalCards, 12);
    expect(summaries.first.masteryPercent, 17); // 8 / 48 * 100 -> 17
    expect(summaries.last.masteryPercent, 50); // 8 / 16 * 100
  });

  test('recentCompletedSessionsProvider passes the repository result through',
      () async {
    final result =
        await container.read(recentCompletedSessionsProvider.future);

    expect(result.single.deckId, 'd1');
    expect(stats.calls, contains('fetchRecentCompletedSessions(limit=20)'));
  });

  test('recentActivityProvider merges sessions, decks and courses, newest first',
      () async {
    final feed = await container.read(recentActivityProvider.future);

    // Newest first: d1's session completed Aug 20, then d1 created Aug 1, then
    // the two courses (fakeCourse stamps 2026-01-01). d2/d3 carry no createdAt
    // and so contribute no "deck created" row.
    expect(feed.first.kind, ActivityKind.sessionCompleted);
    expect(feed.first.title, 'd1');
    expect(feed.first.masteryDelta, 9);
    expect(
      feed.map((i) => i.kind),
      contains(ActivityKind.deckCreated),
    );
  });

  test('deckRunThroughsProvider passes the repository result through', () async {
    expect(
      await container.read(deckRunThroughsProvider.future),
      {'d1': 3, 'd3': 1},
    );
    expect(stats.calls, contains('fetchDeckRunThroughs()'));
  });
}
