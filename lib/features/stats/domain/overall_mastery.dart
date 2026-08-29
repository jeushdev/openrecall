import '../../decks/domain/card.dart';
import '../../decks/domain/deck.dart';

/// The single app-wide mastery figure (engine-v2-spec §6): every card's
/// `mastery_level` across every deck, scaled 0–100 and rounded.
///
/// **Card-weighted** — a large deck dominates a small one — because it sums the
/// raw levels ([DeckSummary.masteryLevelSum]) and card counts before dividing,
/// rather than averaging each deck's already-rounded `masteryPercent`.
///
/// Pure: takes the deck list the app has already fetched, touches no database
/// and no provider. An empty list (or all-empty decks) is 0%.
int overallMasteryPercent(Iterable<DeckSummary> decks) {
  var sum = 0;
  var count = 0;
  for (final deck in decks) {
    sum += deck.masteryLevelSum;
    count += deck.totalCards;
  }
  return masteryPercentFromLevelSum(sum, count);
}
