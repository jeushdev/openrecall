import '../../decks/domain/card.dart';

/// The 0–4 Unfamiliar…Mastered scale the user picks directly in Flip mode
/// (spec §5A / §6). For Flip the translation to `cards.mastery_level` is the
/// identity map — [level] is just the enum index.
enum FlipRating { unfamiliar, forgotten, okay, familiar, mastered }

extension FlipRatingX on FlipRating {
  /// The `mastery_level` this rating writes (0–4).
  int get level => index;

  /// The button label on the rating bar.
  String get label => switch (this) {
        FlipRating.unfamiliar => 'Unfamiliar',
        FlipRating.forgotten => 'Forgotten',
        FlipRating.okay => 'Okay',
        FlipRating.familiar => 'Familiar',
        FlipRating.mastered => 'Mastered',
      };

  /// Whether this rating reaches Mastered.
  bool get isMastered => level >= masteredLevel;

  /// A "fail" is any result short of Mastered (spec §6) — it drives both the
  /// requeue and the `consecutive_fails` counter.
  bool get isFail => !isMastered;
}
