import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/domain/course_summary.dart';

import '../../support/fake_course_repository.dart';

DeckSummary _deck({
  required String id,
  String? courseId,
  required int totalCards,
  required int masteryLevelSum,
}) => DeckSummary(
  id: id,
  name: id,
  lastStudiedAt: null,
  totalCards: totalCards,
  dueCards: totalCards,
  masteryPercent: 0,
  courseId: courseId,
  masteryLevelSum: masteryLevelSum,
);

void main() {
  group('rollUpCourses', () {
    test('groups decks by course_id and card-weights the mastery %', () {
      final courses = [
        fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green'),
        fakeCourse(id: 'c2', name: 'History', accentColor: 'amber'),
      ];
      final decks = [
        _deck(id: 'd1', courseId: 'c1', totalCards: 2, masteryLevelSum: 8),
        _deck(id: 'd2', courseId: 'c1', totalCards: 10, masteryLevelSum: 0),
        _deck(id: 'd3', courseId: 'c2', totalCards: 4, masteryLevelSum: 8),
      ];

      final summaries = rollUpCourses(courses, decks);

      expect(summaries, hasLength(2));

      final bio = summaries.first;
      expect(bio.id, 'c1');
      expect(bio.name, 'Biology');
      expect(bio.accentColor, 'green');
      expect(bio.deckCount, 2);
      expect(bio.totalCards, 12);
      // 8 / (12 * 4) * 100 = 16.67 -> 17  (card-weighted, not deck-averaged)
      expect(bio.masteryPercent, 17);

      final history = summaries.last;
      expect(history.deckCount, 1);
      expect(history.totalCards, 4);
      expect(history.masteryPercent, 50);
    });

    test('a course with no decks rolls up to zeros', () {
      final summaries = rollUpCourses([fakeCourse(id: 'c1')], const []);

      expect(summaries.single.deckCount, 0);
      expect(summaries.single.totalCards, 0);
      expect(summaries.single.masteryPercent, 0);
    });

    test('decks with a null or unknown course_id are excluded', () {
      final decks = [
        _deck(id: 'd1', courseId: 'c1', totalCards: 4, masteryLevelSum: 16),
        _deck(id: 'd2', courseId: null, totalCards: 4, masteryLevelSum: 0),
        _deck(id: 'd3', courseId: 'ghost', totalCards: 4, masteryLevelSum: 0),
      ];

      final summaries = rollUpCourses([fakeCourse(id: 'c1')], decks);

      expect(summaries.single.deckCount, 1);
      expect(summaries.single.totalCards, 4);
      expect(summaries.single.masteryPercent, 100);
    });

    test('preserves the course input order', () {
      final courses = [
        fakeCourse(id: 'z'),
        fakeCourse(id: 'a'),
        fakeCourse(id: 'm'),
      ];

      expect(rollUpCourses(courses, const []).map((s) => s.id), [
        'z',
        'a',
        'm',
      ]);
    });

    test('runs with no ProviderContainer or database', () {
      expect(
        rollUpCourses([fakeCourse(id: 'c1')], const []),
        isA<List<CourseSummary>>(),
      );
    });
  });
}
