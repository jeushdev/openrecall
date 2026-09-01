import 'package:flutter/foundation.dart';

import '../../courses/domain/course.dart';
import '../../decks/domain/deck.dart';
import 'completed_session_activity.dart';

/// How many items the Mastery tab's activity feed holds (milestone C). The feed
/// is a recent-activity glance, not a full history.
const int activityFeedLimit = 20;

/// The kinds of event the feed merges. Every completed session is single-deck
/// (`study_sessions.deck_id` is NOT NULL), so "session completed" and "deck
/// completed" are the same row — [sessionCompleted] covers both.
enum ActivityKind { sessionCompleted, deckCreated, courseCreated }

/// One row in the feed: an icon-worthy [kind], the moment it happened, the name
/// of the deck or course involved, and — for a completed session — the run's
/// mastery delta so the row can show the same "+X%" the Session Summary does.
@immutable
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.timestamp,
    required this.title,
    this.masteryDelta,
  });

  final ActivityKind kind;
  final DateTime timestamp;
  final String title;
  final int? masteryDelta;

  @override
  bool operator ==(Object other) =>
      other is ActivityItem &&
      other.kind == kind &&
      other.timestamp == timestamp &&
      other.title == title &&
      other.masteryDelta == masteryDelta;

  @override
  int get hashCode => Object.hash(kind, timestamp, title, masteryDelta);
}

/// Builds the feed from data the app already holds: completed [sessions], the
/// [decks] list, and the [courses] list. Merges the three sources, sorts newest
/// first, and caps the result at [limit].
///
/// Pure. A session whose `deckId` matches no deck in [decks] is dropped (a
/// deleted deck, or one the offline mirror hasn't seen — same rule as
/// `deckCompletions`). A deck with no known `createdAt` is dropped from the
/// "deck created" source for the same reason.
List<ActivityItem> buildActivityFeed({
  required Iterable<CompletedSessionActivity> sessions,
  required Iterable<DeckSummary> decks,
  required Iterable<Course> courses,
  int limit = activityFeedLimit,
}) {
  final nameByDeckId = {for (final deck in decks) deck.id: deck.name};

  final items = <ActivityItem>[
    for (final session in sessions)
      if (nameByDeckId[session.deckId] case final deckName?)
        ActivityItem(
          kind: ActivityKind.sessionCompleted,
          timestamp: session.completedAt,
          title: deckName,
          masteryDelta: session.masteryDelta,
        ),
    for (final deck in decks)
      if (deck.createdAt case final createdAt?)
        ActivityItem(
          kind: ActivityKind.deckCreated,
          timestamp: createdAt,
          title: deck.name,
        ),
    for (final course in courses)
      ActivityItem(
        kind: ActivityKind.courseCreated,
        timestamp: course.createdAt,
        title: course.name,
      ),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return items.length > limit ? items.sublist(0, limit) : items;
}
