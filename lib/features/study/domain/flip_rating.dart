import '../../decks/domain/card.dart';

/// The 4-point Unfamiliar…Mastered scale the user picks directly in Flip mode
/// (spec §5A / §6). The rating row offers four choices — Unfamiliar, Forgotten,
/// Familiar, Mastered — and each maps to a fixed `cards.mastery_level` (0, 1, 3,
/// 4). The gap at 2 is deliberate: the old "Okay" step was dropped from the UI
/// but the surviving levels keep their original numeric values so historical
/// rows and the DB schema stay compatible.
enum FlipRating { unfamiliar, forgotten, familiar, mastered }

extension FlipRatingX on FlipRating {
  /// The `mastery_level` this rating writes. Not the enum index — the mapping is
  /// explicit so removing "Okay" (which was level 2) didn't renumber the rest.
  int get level => switch (this) {
    FlipRating.unfamiliar => 0,
    FlipRating.forgotten => 1,
    FlipRating.familiar => 3,
    FlipRating.mastered => 4,
  };

  /// The button label on the rating bar.
  String get label => switch (this) {
    FlipRating.unfamiliar => 'Unfamiliar',
    FlipRating.forgotten => 'Forgotten',
    FlipRating.familiar => 'Familiar',
    FlipRating.mastered => 'Mastered',
  };

  /// Whether this rating reaches Mastered.
  bool get isMastered => level >= masteredLevel;

  /// A "fail" is any result short of Mastered (spec §6) — it drives both the
  /// requeue and the `consecutive_fails` counter.
  bool get isFail => !isMastered;
}
