import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/home/application/home_providers.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/domain/active_session.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';

DeckSummary _deck({
  required String id,
  String? courseId,
  int totalCards = 0,
  DateTime? lastStudiedAt,
}) => DeckSummary(
  id: id,
  name: 'Deck $id',
  lastStudiedAt: lastStudiedAt,
  totalCards: totalCards,
  dueCards: totalCards,
  masteryPercent: 0,
  courseId: courseId,
);

ActiveSessionProgress _active({
  required String deckId,
  int mastered = 0,
  int total = 0,
  StudyMode mode = StudyMode.flip,
  DateTime? startedAt,
}) => ActiveSessionProgress(
  sessionId: 's-$deckId',
  deckId: deckId,
  studyMode: mode,
  lengthMode: SessionLengthMode.untilMastered,
  cardScope: CardScope.all,
  cappedLength: null,
  startedAt: startedAt ?? DateTime(2026, 9, 1),
  masteredCards: mastered,
  totalCards: total,
);

void main() {
  late FakeDeckRepository decks;
  late FakeCourseRepository courses;
  late FakeStatsRepository stats;

  ProviderContainer build() {
    final c = ProviderContainer(
      overrides: [
        deckRepositoryProvider.overrideWithValue(decks),
        courseRepositoryProvider.overrideWithValue(courses),
        statsRepositoryProvider.overrideWithValue(stats),
      ],
    );
    c.listen(decksProvider, (_, _) {});
    c.listen(coursesProvider, (_, _) {});
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    decks = FakeDeckRepository(
      decks: [
        _deck(id: 'd1', courseId: 'c1', totalCards: 10),
        _deck(id: 'd2', courseId: 'c2', totalCards: 4),
        _deck(id: 'd3', totalCards: 2),
      ],
    );
    courses = FakeCourseRepository(
      courses: [
        fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green'),
        fakeCourse(id: 'c2', name: 'History', accentColor: 'amber'),
      ],
    );
    stats = FakeStatsRepository();
  });

  group('activeSessionsProvider', () {
    test('joins each active session to its deck name and percent', () async {
      stats = FakeStatsRepository(
        activeSessions: [
          _active(deckId: 'd1', mastered: 3, total: 12, mode: StudyMode.cloze),
        ],
      );
      final result = await build().read(activeSessionsProvider.future);
      expect(result, hasLength(1));
      expect(result.single.deckName, 'Deck d1');
      expect(result.single.studyMode, StudyMode.cloze);
      expect(result.single.percentComplete, 25);
    });

    test('drops sessions whose deck is not in the deck list', () async {
      stats = FakeStatsRepository(
        activeSessions: [
          _active(deckId: 'd1', mastered: 1, total: 2),
          _active(deckId: 'gone', mastered: 0, total: 5),
        ],
      );
      final result = await build().read(activeSessionsProvider.future);
      expect(result.map((s) => s.deckId), ['d1']);
    });

    test('is empty when there are no active sessions', () async {
      expect(await build().read(activeSessionsProvider.future), isEmpty);
      expect(stats.calls, contains('fetchActiveSessions()'));
    });
  });

  group('mostReviewedDecksProvider', () {
    test('orders by completed-session count, descending', () async {
      stats = FakeStatsRepository(sessionCountsByDeck: {'d2': 5, 'd1': 2});
      final result = await build().read(mostReviewedDecksProvider.future);
      expect(result.map((d) => d.deckId), ['d2', 'd1', 'd3']);
      expect(result.first.sessionCount, 5);
    });

    test('breaks count ties by most recently studied', () async {
      decks = FakeDeckRepository(
        decks: [
          _deck(id: 'd1', lastStudiedAt: DateTime(2026, 8, 1)),
          _deck(id: 'd2', lastStudiedAt: DateTime(2026, 8, 20)),
        ],
      );
      stats = FakeStatsRepository(sessionCountsByDeck: {'d1': 3, 'd2': 3});
      final result = await build().read(mostReviewedDecksProvider.future);
      expect(result.map((d) => d.deckId), ['d2', 'd1']);
    });

    test(
      'carries the course name and accent, null for a course-less deck',
      () async {
        stats = FakeStatsRepository(sessionCountsByDeck: {'d1': 1});
        final result = await build().read(mostReviewedDecksProvider.future);
        final byId = {for (final d in result) d.deckId: d};
        expect(byId['d1']!.courseName, 'Biology');
        expect(byId['d1']!.accentColor, 'green');
        expect(byId['d3']!.courseName, isNull);
        expect(byId['d3']!.accentColor, 'slate');
      },
    );

    test('caps the list at mostReviewedDecksLimit', () async {
      decks = FakeDeckRepository(
        decks: [for (var i = 0; i < 10; i++) _deck(id: 'd$i')],
      );
      final result = await build().read(mostReviewedDecksProvider.future);
      expect(result, hasLength(mostReviewedDecksLimit));
    });
  });
}
