import 'flip_rating.dart';

/// The result of one Cloze card attempt, translated onto the shared 0–4
/// `mastery_level` scale (spec §6):
/// - [correct] — the typed answer matched (exactly or via fuzzy match) on the
///   single check → Mastered.
/// - [overridden] — the answer was marked wrong but the user tapped
///   "I was right" → Familiar.
/// - [missed] — marked wrong, no override → Forgotten.
enum ClozeOutcome { correct, overridden, missed }

extension ClozeOutcomeX on ClozeOutcome {
  /// The `cards.mastery_level` this outcome writes.
  int get masteryLevel => switch (this) {
    ClozeOutcome.correct => FlipRating.mastered.level,
    ClozeOutcome.overridden => FlipRating.familiar.level,
    ClozeOutcome.missed => FlipRating.forgotten.level,
  };
}
