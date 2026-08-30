import 'package:flutter/foundation.dart';

import 'card.dart';
import 'study_mode.dart';

/// The lifetime `fail_count` a card needs before it shows up under
/// "Troublemaker cards" (spec §4), and how many are listed.
const int _troublemakerMinFails = 1;
const int _troublemakerLimit = 5;

/// Everything the Deck Overview screen (spec §4) derives from a deck's cards:
/// headline stats, which study modes the deck supports, and the Troublemaker
/// list. Pure — built from the card list the existing `deckCardsProvider`
/// already fetches, with no extra query.
@immutable
class DeckOverviewStats {
  const DeckOverviewStats({
    required this.totalCards,
    required this.dueCards,
    required this.masteryPercent,
    required this.withKeyword,
    required this.multiLine,
    required this.modes,
    required this.troublemakers,
  });

  factory DeckOverviewStats.fromCards(List<FlashCard> cards) {
    final troublemakers = cards
        .where((c) => c.failCount >= _troublemakerMinFails)
        .toList()
      ..sort((a, b) => b.failCount.compareTo(a.failCount));

    return DeckOverviewStats(
      totalCards: cards.length,
      dueCards: cards.where((c) => c.isDue).length,
      masteryPercent: masteryPercentFromLevels(cards.map((c) => c.masteryLevel)),
      withKeyword: cards.where(cardHasKeywords).length,
      multiLine: cards.where(cardIsMultiLine).length,
      modes: availableModes(cards),
      troublemakers: List.unmodifiable(
        troublemakers.take(_troublemakerLimit),
      ),
    );
  }

  final int totalCards;
  final int dueCards;
  final int masteryPercent;
  final int withKeyword;
  final int multiLine;
  final Set<StudyMode> modes;
  final List<FlashCard> troublemakers;

  bool get isEmpty => totalCards == 0;

  /// A deck that has cards but nothing left below Mastered (spec §4 empty state).
  bool get allCaughtUp => totalCards > 0 && dueCards == 0;

  bool supports(StudyMode mode) => modes.contains(mode);
}
