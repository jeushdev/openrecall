import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/troublemaker_card.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck({
  required String id,
  String? courseId,
  required int totalCards,
  required int masteryLevelSum,
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
    );

TroublemakerCard _troublemaker(String id, int failCount) => TroublemakerCard(
      id: id,
      deckId: 'deck-1',
      front: 'front $id',
      back: 'back $id',
      failCount: failCount,
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
      _deck(id: 'd1', courseId: 'c1', totalCards: 2, masteryLevelSum: 8),
      _deck(id: 'd2', courseId: 'c1', totalCards: 10, masteryLevelSum: 0),
      _deck(id: 'd3', courseId: 'c2', totalCards: 4, masteryLevelSum: 8),
    ]);
    courses = FakeCourseRepository(courses: [
      fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green'),
      fakeCourse(id: 'c2', name: 'History'),
    ]);
    stats = FakeStatsRepository(
      troublemakers: [_troublemaker('a', 9), _troublemaker('b', 4)],
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

  test('troublemakersProvider passes the repository result through', () async {
    final result = await container.read(troublemakersProvider.future);

    expect(result.map((c) => c.id), ['a', 'b']);
    expect(stats.calls, contains('fetchTroublemakers(limit=20)'));
  });

  test('deckRunThroughsProvider passes the repository result through', () async {
    expect(
      await container.read(deckRunThroughsProvider.future),
      {'d1': 3, 'd3': 1},
    );
    expect(stats.calls, contains('fetchDeckRunThroughs()'));
  });
}
