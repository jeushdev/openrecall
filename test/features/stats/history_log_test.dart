import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/stats/domain/history_log.dart';

import '../../support/fake_course_repository.dart';

DeckSummary _deck(String id, String name, {String? courseId}) => DeckSummary(
  id: id,
  name: name,
  lastStudiedAt: null,
  totalCards: 0,
  dueCards: 0,
  masteryPercent: 0,
  courseId: courseId,
);

CompletedSessionActivity _session(
  String deckId,
  DateTime at, {
  StudyMode mode = StudyMode.flip,
  int? cards = 6,
  int? delta = 4,
}) => CompletedSessionActivity(
  deckId: deckId,
  completedAt: at,
  masteryDelta: delta,
  studyMode: mode,
  cardsReviewed: cards,
);

void main() {
  final courses = [fakeCourse(id: 'c1', name: 'Biology', accentColor: 'green')];

  group('buildHistoryLog', () {
    test('joins sessions to deck + course, newest first', () {
      final log = buildHistoryLog(
        sessions: [
          _session('d1', DateTime(2026, 8, 18)),
          _session('d1', DateTime(2026, 8, 20), mode: StudyMode.cloze),
        ],
        decks: [_deck('d1', 'Cells', courseId: 'c1')],
        courses: courses,
      );

      expect(log.map((e) => e.completedAt), [
        DateTime(2026, 8, 20),
        DateTime(2026, 8, 18),
      ]);
      expect(log.first.deckName, 'Cells');
      expect(log.first.courseName, 'Biology');
      expect(log.first.accentColor, 'green');
      expect(log.first.studyMode, StudyMode.cloze);
    });

    test('drops a session whose deck is unknown', () {
      final log = buildHistoryLog(
        sessions: [_session('gone', DateTime(2026, 8, 20))],
        decks: [_deck('d1', 'Cells', courseId: 'c1')],
        courses: courses,
      );

      expect(log, isEmpty);
    });

    test(
      'falls back to the slate accent and null course for a course-less deck',
      () {
        final log = buildHistoryLog(
          sessions: [_session('d2', DateTime(2026, 8, 20))],
          decks: [_deck('d2', 'Loose')],
          courses: courses,
        );

        expect(log.single.courseName, isNull);
        expect(log.single.accentColor, 'slate');
      },
    );
  });

  group('groupHistoryByDeck', () {
    test('groups entries per deck, groups ordered by most recent entry', () {
      final log = buildHistoryLog(
        sessions: [
          _session('d1', DateTime(2026, 8, 10)),
          _session('d2', DateTime(2026, 8, 20)),
          _session('d1', DateTime(2026, 8, 5)),
        ],
        decks: [
          _deck('d1', 'Cells', courseId: 'c1'),
          _deck('d2', 'Genes', courseId: 'c1'),
        ],
        courses: courses,
      );

      final groups = groupHistoryByDeck(log);
      expect(groups.map((g) => g.deckId), ['d2', 'd1']);
      expect(groups.last.entries, hasLength(2));
    });
  });
}
