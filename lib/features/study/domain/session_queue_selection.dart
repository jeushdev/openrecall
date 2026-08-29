import '../../decks/domain/card.dart';
import '../../decks/domain/study_mode.dart';
import 'queue_seed.dart';

/// The gap between adjacent `session_cards.position` values. Sparse (steps of
/// 1000, not 1) so a requeue can slot between existing values without
/// renumbering the rest of the queue (spec §5).
const int kPositionStep = 1000;

/// The cards from [cards] that structurally support [mode] (spec §4):
/// Flip has no filter, Cloze needs a keyword, List/Feynman need 2+ lines on a
/// side. Order is preserved.
Iterable<FlashCard> cardsSupportingMode(
  Iterable<FlashCard> cards,
  StudyMode mode,
) =>
    switch (mode) {
      StudyMode.flip => cards,
      StudyMode.cloze => cards.where(cardHasKeyword),
      StudyMode.list || StudyMode.feynman => cards.where(cardIsMultiLine),
    };

/// The queue for a new session (spec §4): every card below Mastered, then
/// filtered to the ones that support [mode], then — only if [cap] is non-null —
/// truncated to the first [cap] cards. Creation order (the order of [cards]) is
/// preserved throughout.
List<FlashCard> selectSessionCards({
  required List<FlashCard> cards,
  required StudyMode mode,
  required int? cap,
}) {
  final supported =
      cardsSupportingMode(cards.where((c) => c.isDue), mode).toList();
  if (cap == null || cap >= supported.length) return supported;
  return supported.take(cap).toList();
}

/// Turns the ordered queue into [QueueSeed]s with sparse positions
/// (1000, 2000, 3000, …).
List<QueueSeed> seedsFrom(List<FlashCard> ordered) => [
      for (var i = 0; i < ordered.length; i++)
        QueueSeed(cardId: ordered[i].id, position: (i + 1) * kPositionStep),
    ];
