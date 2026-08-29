import 'package:flutter/foundation.dart';

/// Throwaway mock models + sample data for the Decks tab (ui-spec-v1 §6.1).
///
/// The real screen will read decks from the cache-first repository and their
/// parent course from `CourseRepository`, joining on `deck.course_id`. That
/// wiring is deliberately out of scope for milestone U4 — this milestone builds
/// the tab's UI only — so the grid renders against these fixtures. Delete this
/// file once the providers land.
///
/// [MockDeck.dueCount] stands in for the deck's due-card count; [clearedCount]
/// stands in for the per-deck run-through count from §7
/// (`count(*) from study_sessions where card_scope='all' and status='completed'`).

/// A stand-in for a `courses` row — only the fields the deck tile needs.
@immutable
class MockCourse {
  const MockCourse({required this.name, required this.accentColor});

  final String name;

  /// One of the eight named `courses.accent_color` keys
  /// (`slate`, `red`, `amber`, `green`, `teal`, `blue`, `violet`, `pink`).
  final String accentColor;
}

/// A stand-in for a `decks` row plus its resolved parent course and the two
/// counts the tile badges show.
@immutable
class MockDeck {
  const MockDeck({
    required this.name,
    required this.course,
    required this.dueCount,
    required this.clearedCount,
  });

  final String name;
  final MockCourse course;

  /// Cards due today — drives the **Due** segment badge.
  final int dueCount;

  /// Completed `card_scope: 'all'` run-throughs — drives the **All** segment
  /// badge (§7).
  final int clearedCount;
}

const _biology = MockCourse(name: 'Biology 101', accentColor: 'green');
const _history = MockCourse(name: 'Modern History', accentColor: 'amber');
const _chemistry = MockCourse(name: 'Organic Chemistry', accentColor: 'teal');
const _spanish = MockCourse(name: 'Spanish', accentColor: 'red');
const _uncategorised = MockCourse(name: 'Uncategorised', accentColor: 'slate');

/// Sample decks spanning several accent keys and covering both zero-count edge
/// cases (a deck with nothing due, and a deck never run through in "all" mode).
const List<MockDeck> sampleMockDecks = [
  MockDeck(name: 'Cell structure', course: _biology, dueCount: 12, clearedCount: 3),
  MockDeck(name: 'Photosynthesis', course: _biology, dueCount: 0, clearedCount: 1),
  MockDeck(
    name: 'The interwar period',
    course: _history,
    dueCount: 5,
    clearedCount: 0,
  ),
  MockDeck(name: 'Cold War treaties', course: _history, dueCount: 21, clearedCount: 7),
  MockDeck(
    name: 'Functional groups',
    course: _chemistry,
    dueCount: 8,
    clearedCount: 2,
  ),
  MockDeck(name: 'Common verbs', course: _spanish, dueCount: 0, clearedCount: 0),
  MockDeck(
    name: 'Loose flashcards',
    course: _uncategorised,
    dueCount: 3,
    clearedCount: 0,
  ),
];
