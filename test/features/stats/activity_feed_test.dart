import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/domain/activity_feed.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';

DeckSummary _deck(String id, String name, DateTime createdAt) => DeckSummary(
  id: id,
  name: name,
  lastStudiedAt: null,
  totalCards: 0,
  dueCards: 0,
  masteryPercent: 0,
  createdAt: createdAt,
);

Course _course(String id, String name, DateTime createdAt) => Course(
  id: id,
  userId: 'u1',
  name: name,
  accentColor: 'slate',
  isDefault: false,
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  test(
    'merges sessions, decks and courses into one timestamp-descending list',
    () {
      final feed = buildActivityFeed(
        sessions: [
          CompletedSessionActivity(
            deckId: 'd1',
            completedAt: DateTime(2026, 8, 20),
            masteryDelta: 8,
            studyMode: StudyMode.flip,
          ),
        ],
        decks: [
          _deck('d1', 'Biology', DateTime(2026, 8, 10)),
          _deck('d2', 'Spanish', DateTime(2026, 8, 25)),
        ],
        courses: [_course('c1', 'Medicine', DateTime(2026, 8, 15))],
      );

      expect(feed.map((i) => (i.kind, i.title)).toList(), [
        (ActivityKind.deckCreated, 'Spanish'), // Aug 25
        (ActivityKind.sessionCompleted, 'Biology'), // Aug 20
        (ActivityKind.courseCreated, 'Medicine'), // Aug 15
        (ActivityKind.deckCreated, 'Biology'), // Aug 10
      ]);
    },
  );

  test('a completed session carries its mastery delta', () {
    final feed = buildActivityFeed(
      sessions: [
        CompletedSessionActivity(
          deckId: 'd1',
          completedAt: DateTime(2026, 8, 20),
          masteryDelta: 8,
          studyMode: StudyMode.flip,
        ),
      ],
      decks: [_deck('d1', 'Biology', DateTime(2026, 8, 10))],
      courses: const [],
    );

    expect(feed.first.masteryDelta, 8);
  });

  test('caps the feed at the given limit, keeping the most recent', () {
    final decks = [
      for (var i = 0; i < 30; i++)
        _deck('d$i', 'Deck $i', DateTime(2026, 8, 1).add(Duration(days: i))),
    ];

    final feed = buildActivityFeed(
      sessions: const [],
      decks: decks,
      courses: const [],
      limit: 20,
    );

    expect(feed, hasLength(20));
    expect(feed.first.title, 'Deck 29');
    expect(feed.last.title, 'Deck 10');
  });

  test('a session whose deck is unknown is dropped', () {
    final feed = buildActivityFeed(
      sessions: [
        CompletedSessionActivity(
          deckId: 'gone',
          completedAt: DateTime(2026, 8, 20),
          masteryDelta: 3,
          studyMode: StudyMode.flip,
        ),
      ],
      decks: const [],
      courses: const [],
    );

    expect(feed, isEmpty);
  });

  test('a deck with no known creation time is dropped', () {
    final feed = buildActivityFeed(
      sessions: const [],
      decks: [
        DeckSummary(
          id: 'd1',
          name: 'Biology',
          lastStudiedAt: null,
          totalCards: 0,
          dueCards: 0,
          masteryPercent: 0,
        ),
      ],
      courses: const [],
    );

    expect(feed, isEmpty);
  });
}
