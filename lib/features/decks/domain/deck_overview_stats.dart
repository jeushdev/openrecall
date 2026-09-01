import 'package:flutter/foundation.dart';

import 'card.dart';
import 'study_mode.dart';

/// Everything the Deck Overview screen (spec §4) derives from a deck's cards:
/// headline stats and which study modes the deck supports. Pure — built from the
/// card list the existing `deckCardsProvider` already fetches, with no extra
/// query.
@immutable
class DeckOverviewStats {
  const DeckOverviewStats({
    required this.totalCards,
    required this.dueCards,
    required this.masteryPercent,
    required this.withKeyword,
    required this.multiLine,
    required this.modes,
  });

  factory DeckOverviewStats.fromCards(List<FlashCard> cards) {
    return DeckOverviewStats(
      totalCards: cards.length,
      dueCards: cards.where((c) => c.isDue).length,
      masteryPercent: masteryPercentFromLevels(cards.map((c) => c.masteryLevel)),
      withKeyword: cards.where(cardHasKeywords).length,
      multiLine: cards.where(cardIsMultiLine).length,
      modes: availableModes(cards),
    );
  }

  final int totalCards;
  final int dueCards;
  final int masteryPercent;
  final int withKeyword;
  final int multiLine;
  final Set<StudyMode> modes;

  bool get isEmpty => totalCards == 0;

  /// A deck that has cards but nothing left below Mastered (spec §4 empty state).
  bool get allCaughtUp => totalCards > 0 && dueCards == 0;

  bool supports(StudyMode mode) => modes.contains(mode);
}
