import 'package:flutter/foundation.dart';

/// A finished study session as the Mastery tab's activity feed needs it
/// (milestone C): just the deck it covered, when it wrapped up, and the run's
/// whole-deck mastery delta.
///
/// Sourced from `study_sessions` rows with `status = 'completed'` (or the
/// `offline_study_sessions` mirror). Deliberately lean — the feed shows a deck
/// name and a "+X%", nothing per-card. Milestone D reuses the same rows for its
/// session-count and streak metrics.
@immutable
class CompletedSessionActivity {
  const CompletedSessionActivity({
    required this.deckId,
    required this.completedAt,
    required this.masteryDelta,
  });

  final String deckId;
  final DateTime completedAt;

  /// `study_sessions.mastery_delta` — nullable for legacy rows written before
  /// the column was populated.
  final int? masteryDelta;

  @override
  bool operator ==(Object other) =>
      other is CompletedSessionActivity &&
      other.deckId == deckId &&
      other.completedAt == completedAt &&
      other.masteryDelta == masteryDelta;

  @override
  int get hashCode => Object.hash(deckId, completedAt, masteryDelta);
}
