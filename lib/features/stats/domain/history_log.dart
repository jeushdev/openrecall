import 'package:flutter/foundation.dart';

import '../../courses/domain/course.dart';
import '../../decks/domain/deck.dart';
import '../../decks/domain/study_mode.dart';
import 'completed_session_activity.dart';

/// One row in the History tab's session log (ui-spec-v4 §4): a completed study
/// session, resolved to its deck and course so the row can show a deck name, a
/// course-accent left bar, the mode + card count, a relative time and the run's
/// mastery delta.
///
/// Derived, never stored — see [buildHistoryLog].
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.deckId,
    required this.deckName,
    required this.courseName,
    required this.accentColor,
    required this.studyMode,
    required this.cardsReviewed,
    required this.completedAt,
    required this.masteryDelta,
  });

  final String deckId;
  final String deckName;

  /// The deck's course name, or `null` for a deck whose course the local mirror
  /// hasn't seen. Used as the "By Deck" grouping label alongside [deckName].
  final String? courseName;

  /// The course's accent key (`slate` fallback), mapped to a colour via
  /// `AppTokens.accent`.
  final String accentColor;
  final StudyMode studyMode;
  final int? cardsReviewed;
  final DateTime completedAt;
  final int? masteryDelta;

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.deckId == deckId &&
      other.deckName == deckName &&
      other.courseName == courseName &&
      other.accentColor == accentColor &&
      other.studyMode == studyMode &&
      other.cardsReviewed == cardsReviewed &&
      other.completedAt == completedAt &&
      other.masteryDelta == masteryDelta;

  @override
  int get hashCode => Object.hash(
    deckId,
    deckName,
    courseName,
    accentColor,
    studyMode,
    cardsReviewed,
    completedAt,
    masteryDelta,
  );
}

/// Joins [sessions] (the `recentCompletedSessionsProvider` list) against [decks]
/// and [courses] to attach display names and an accent, newest first.
///
/// Pure: every input is something the app has already fetched. A session whose
/// `deckId` matches no deck in [decks] is dropped — a deleted deck, or one the
/// local mirror hasn't seen (same rule as `buildActivityFeed` / `deckCompletions`).
List<HistoryEntry> buildHistoryLog({
  required Iterable<CompletedSessionActivity> sessions,
  required Iterable<DeckSummary> decks,
  required Iterable<Course> courses,
}) {
  final deckById = {for (final deck in decks) deck.id: deck};
  final courseById = {for (final course in courses) course.id: course};

  final entries = <HistoryEntry>[
    for (final session in sessions)
      if (deckById[session.deckId] case final deck?)
        HistoryEntry(
          deckId: deck.id,
          deckName: deck.name,
          courseName: courseById[deck.courseId]?.name,
          accentColor: courseById[deck.courseId]?.accentColor ?? 'slate',
          studyMode: session.studyMode,
          cardsReviewed: session.cardsReviewed,
          completedAt: session.completedAt,
          masteryDelta: session.masteryDelta,
        ),
  ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  return entries;
}

/// One "By Deck" group in the session log: a deck (with its course label and
/// accent) and its entries, newest first. Groups are ordered by their most
/// recent entry.
@immutable
class HistoryDeckGroup {
  const HistoryDeckGroup({
    required this.deckId,
    required this.deckName,
    required this.courseName,
    required this.accentColor,
    required this.entries,
  });

  final String deckId;
  final String deckName;
  final String? courseName;
  final String accentColor;
  final List<HistoryEntry> entries;
}

/// Folds a flat [entries] list (already newest-first, from [buildHistoryLog])
/// into per-deck groups for the log's "By Deck" view, groups ordered by their
/// most recent entry.
List<HistoryDeckGroup> groupHistoryByDeck(List<HistoryEntry> entries) {
  final order = <String>[];
  final byDeck = <String, List<HistoryEntry>>{};
  for (final entry in entries) {
    final bucket = byDeck.putIfAbsent(entry.deckId, () {
      order.add(entry.deckId);
      return <HistoryEntry>[];
    });
    bucket.add(entry);
  }
  return [
    for (final deckId in order)
      HistoryDeckGroup(
        deckId: deckId,
        deckName: byDeck[deckId]!.first.deckName,
        courseName: byDeck[deckId]!.first.courseName,
        accentColor: byDeck[deckId]!.first.accentColor,
        entries: byDeck[deckId]!,
      ),
  ];
}
