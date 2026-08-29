import 'flip_rating.dart';

/// Translates a List card attempt onto the shared 0–4 `mastery_level` scale
/// (spec §5C / §6), from the ratio of content lines the user had to reveal
/// before recalling the rest:
/// - 0 reveals → Mastered
/// - up to a third revealed → Familiar
/// - up to two thirds revealed → Okay
/// - more than two thirds (or every line) revealed → Forgotten
///
/// [total] is the number of content lines; a card with no content lines can't
/// reach here in practice, but is treated as Mastered defensively.
int listMasteryFromReveals({required int revealed, required int total}) {
  if (total <= 0 || revealed <= 0) return FlipRating.mastered.level;
  final ratio = revealed / total;
  if (ratio <= 1 / 3) return FlipRating.familiar.level;
  if (ratio <= 2 / 3) return FlipRating.okay.level;
  return FlipRating.forgotten.level;
}
