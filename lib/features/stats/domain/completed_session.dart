import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';

/// How many completed sessions the profile-metrics fetch pulls, newest first.
/// One thousand daily sessions is roughly three years of study — beyond that the
/// lifetime totals under-count slightly, an accepted trade for one lean query
/// instead of a server-side aggregate.
const int completedSessionsLimit = 1000;

/// A finished study session as the Profile tab's study metrics need it
/// (offline-and-ux milestone D): when it began, when it wrapped up, and how many
/// cards it covered.
///
/// Sourced from `study_sessions` rows with `status = 'completed'` (or the
/// `offline_study_sessions` mirror). Deliberately lean and distinct from
/// [CompletedSessionActivity] — that model is the Mastery tab feed's newest-20
/// shape and carries the deck and mastery delta instead. This one is the
/// all-history input for streaks, session counts and study-time totals.
@immutable
class CompletedSession {
  const CompletedSession({
    required this.startedAt,
    required this.completedAt,
    required this.cardsReviewed,
    this.sessionId,
    this.deckId,
    this.studyMode,
    this.lengthMode,
    this.cardScope,
    this.cappedLength,
    this.masteryDelta,
  });

  /// Present for durable session rows. Optional for callers that only need the
  /// legacy metrics projection.
  final String? sessionId;
  final String? deckId;
  final StudyMode? studyMode;
  final SessionLengthMode? lengthMode;
  final CardScope? cardScope;
  final int? cappedLength;
  final int? masteryDelta;

  final DateTime startedAt;

  /// `study_sessions.completed_at` — practically always set for a `completed`
  /// row, but nullable so a partially-migrated row does not crash the metrics.
  final DateTime? completedAt;

  /// `study_sessions.cards_reviewed` — the distinct cards the session covered,
  /// stamped at completion. Null for sessions completed before the column
  /// existed and not yet backfilled.
  final int? cardsReviewed;

  @override
  bool operator ==(Object other) =>
      other is CompletedSession &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt &&
      other.cardsReviewed == cardsReviewed &&
      other.sessionId == sessionId &&
      other.deckId == deckId &&
      other.studyMode == studyMode &&
      other.lengthMode == lengthMode &&
      other.cardScope == cardScope &&
      other.cappedLength == cappedLength &&
      other.masteryDelta == masteryDelta;

  @override
  int get hashCode => Object.hash(
    startedAt,
    completedAt,
    cardsReviewed,
    sessionId,
    deckId,
    studyMode,
    lengthMode,
    cardScope,
    cappedLength,
    masteryDelta,
  );
}
