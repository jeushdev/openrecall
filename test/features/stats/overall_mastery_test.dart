import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/domain/overall_mastery.dart';

DeckSummary _deck({
  String id = 'deck',
  required int totalCards,
  required int masteryLevelSum,
}) =>
    DeckSummary(
      id: id,
      name: id,
      lastStudiedAt: null,
      totalCards: totalCards,
      dueCards: totalCards,
      masteryPercent: masteryPercentFromLevels(
        List.filled(totalCards, 0),
      ),
      masteryLevelSum: masteryLevelSum,
    );

void main() {
  group('overallMasteryPercent', () {
    test('no decks is 0%', () {
      expect(overallMasteryPercent(const []), 0);
    });

    test('decks with no cards are 0%', () {
      expect(
        overallMasteryPercent([
          _deck(id: 'a', totalCards: 0, masteryLevelSum: 0),
          _deck(id: 'b', totalCards: 0, masteryLevelSum: 0),
        ]),
        0,
      );
    });

    test('a single deck matches the shared per-deck helper', () {
      // levels [1, 4] -> sum 5 over 2 cards
      expect(
        overallMasteryPercent([
          _deck(totalCards: 2, masteryLevelSum: 5),
        ]),
        masteryPercentFromLevels(const [1, 4]),
      );
    });

    test('is card-weighted: a large unfamiliar deck drags the average down', () {
      // 2 fully-mastered cards (sum 8) + 10 unfamiliar cards (sum 0):
      // card-weighted  = 8 / (12 * 4) * 100  = 16.67 -> 17
      // deck-averaged  = (100 + 0) / 2       = 50   (what we must NOT get)
      final percent = overallMasteryPercent([
        _deck(id: 'small', totalCards: 2, masteryLevelSum: 8),
        _deck(id: 'large', totalCards: 10, masteryLevelSum: 0),
      ]);

      expect(percent, 17);
    });

    test('all cards mastered is 100%', () {
      expect(
        overallMasteryPercent([
          _deck(id: 'a', totalCards: 3, masteryLevelSum: 12),
          _deck(id: 'b', totalCards: 5, masteryLevelSum: 20),
        ]),
        100,
      );
    });

    test('runs with no ProviderContainer or database', () {
      // The function only ever sees plain data — this test existing and passing
      // is the assertion that it has no Riverpod / DB dependency.
      expect(
        overallMasteryPercent([_deck(totalCards: 4, masteryLevelSum: 8)]),
        50,
      );
    });
  });
}
