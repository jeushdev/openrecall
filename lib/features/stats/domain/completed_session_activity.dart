import 'package:flutter/foundation.dart';

import '../../decks/domain/study_mode.dart';
import '../../study/domain/session_length.dart';
import '../../study/domain/study_session.dart';

/// A finished study session as the Mastery tab's activity feed (milestone C)
/// and the History tab's session log (ui-spec-v4 §4) need it: the deck it
/// covered, when it wrapped up, the run's whole-deck mastery delta, and — for
/// the History log's per-row detail — the mode it ran in and how many cards it
/// covered.
///
/// Sourced from `study_sessions` rows with `status = 'completed'` (or the
/// `offline_study_sessions` mirror). Deliberately lean — no per-card data.
/// Milestone D reuses the same rows for its session-count and streak metrics.
@immutable
class CompletedSessionActivity {
  const CompletedSessionActivity({
    required this.deckId,
    required this.completedAt,
    required this.masteryDelta,
    required this.studyMode,
    this.cardsReviewed,
    this.sessionId,
    this.startedAt,
    this.lengthMode,
    this.cardScope,
    this.cappedLength,
  });

  final String? sessionId;
  final DateTime? startedAt;
  final SessionLengthMode? lengthMode;
  final CardScope? cardScope;
  final int? cappedLength;

  final String deckId;
  final DateTime completedAt;

  /// `study_sessions.mastery_delta` — nullable for legacy rows written before
  /// the column was populated.
  final int? masteryDelta;

  /// `study_sessions.study_mode` — always set (the column is NOT NULL).
  final StudyMode studyMode;

  /// `study_sessions.cards_reviewed` — the distinct cards the session covered,
  /// stamped at completion. Null for sessions completed before the column
  /// existed and not yet backfilled.
  final int? cardsReviewed;

  @override
  bool operator ==(Object other) =>
      other is CompletedSessionActivity &&
      other.deckId == deckId &&
      other.completedAt == completedAt &&
      other.masteryDelta == masteryDelta &&
      other.studyMode == studyMode &&
      other.cardsReviewed == cardsReviewed &&
      other.sessionId == sessionId &&
      other.startedAt == startedAt &&
      other.lengthMode == lengthMode &&
      other.cardScope == cardScope &&
      other.cappedLength == cappedLength;

  @override
  int get hashCode => Object.hash(
    deckId,
    completedAt,
    masteryDelta,
    studyMode,
    cardsReviewed,
    sessionId,
    startedAt,
    lengthMode,
    cardScope,
    cappedLength,
  );
}
