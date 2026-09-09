import 'package:flutter/foundation.dart';

import '../../courses/domain/course.dart';
import '../../decks/domain/card.dart';
import '../../decks/domain/deck.dart';

/// Per-course rollup for the future Mastery / Stats screen (engine-v2-spec §6):
/// one course plus the aggregate counts of the decks under it. Derived from the
/// deck list joined by `course_id` — no dedicated query.
@immutable
class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.name,
    required this.accentColor,
    required this.deckCount,
    required this.totalCards,
    required this.masteryPercent,
  });

  final String id;
  final String name;

  /// The course's named accent key (`slate`, `red`, …) — see [Course.accentColor].
  final String accentColor;
  final int deckCount;
  final int totalCards;

  /// Card-weighted mastery % across every deck in the course (0–100). A course
  /// with no cards is 0%.
  final int masteryPercent;

  @override
  bool operator ==(Object other) =>
      other is CourseSummary &&
      other.id == id &&
      other.name == name &&
      other.accentColor == accentColor &&
      other.deckCount == deckCount &&
      other.totalCards == totalCards &&
      other.masteryPercent == masteryPercent;

  @override
  int get hashCode =>
      Object.hash(id, name, accentColor, deckCount, totalCards, masteryPercent);
}

/// Rolls [decks] up under [courses], one [CourseSummary] per course, in the
/// given course order.
///
/// Pure: both inputs are lists the app has already fetched
/// (`coursesProvider` / `decksProvider`); no database, no provider. A deck whose
/// `courseId` is null or matches no course in [courses] is left out of every
/// rollup (it still counts toward [overallMasteryPercent]). A course with no
/// decks rolls up to all zeros.
List<CourseSummary> rollUpCourses(
  List<Course> courses,
  List<DeckSummary> decks,
) {
  final byCourse = <String, List<DeckSummary>>{};
  for (final deck in decks) {
    final courseId = deck.courseId;
    if (courseId == null) continue;
    (byCourse[courseId] ??= <DeckSummary>[]).add(deck);
  }

  return [
    for (final course in courses)
      _summarise(course, byCourse[course.id] ?? const <DeckSummary>[]),
  ];
}

CourseSummary _summarise(Course course, List<DeckSummary> decks) {
  var totalCards = 0;
  var levelSum = 0;
  for (final deck in decks) {
    totalCards += deck.totalCards;
    levelSum += deck.masteryLevelSum;
  }
  return CourseSummary(
    id: course.id,
    name: course.name,
    accentColor: course.accentColor,
    deckCount: decks.length,
    totalCards: totalCards,
    masteryPercent: masteryPercentFromLevelSum(levelSum, totalCards),
  );
}
