import 'flip_rating.dart';

/// Translates a Feynman card attempt onto the shared 0–4 `mastery_level` scale
/// (spec §5D / §6), from the ratio of reference points the user checked off as
/// covered in their own explanation:
/// - everything covered → Mastered
/// - at least two thirds covered → Familiar
/// - at least a third covered → Okay
/// - little or nothing covered → Forgotten
///
/// [total] is the number of reference points; a card with none can't reach here
/// in practice, but is treated as Mastered defensively. Never returns Unfamiliar
/// (0), matching List.
int feynmanMasteryFromCheckoff({required int checked, required int total}) {
  if (total <= 0 || checked >= total) return FlipRating.mastered.level;
  if (checked <= 0) return FlipRating.forgotten.level;
  final ratio = checked / total;
  if (ratio >= 2 / 3) return FlipRating.familiar.level;
  if (ratio >= 1 / 3) return FlipRating.okay.level;
  return FlipRating.forgotten.level;
}
