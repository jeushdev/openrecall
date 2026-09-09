import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/stats/domain/deck_completion.dart';

DeckSummary _deck(String id, String name) => DeckSummary(
  id: id,
  name: name,
  lastStudiedAt: null,
  totalCards: 0,
  dueCards: 0,
  masteryPercent: 0,
);

void main() {
  test('joins run-through counts to deck names, most cleared first', () {
    final result = deckCompletions(
      {'d1': 2, 'd2': 5},
      [_deck('d1', 'Anatomy'), _deck('d2', 'Biochem')],
    );

    expect(result.map((c) => c.deckName), ['Biochem', 'Anatomy']);
    expect(result.map((c) => c.runThroughs), [5, 2]);
  });

  test('breaks ties on deck name, ascending', () {
    final result = deckCompletions(
      {'d1': 3, 'd2': 3},
      [_deck('d1', 'Zoology'), _deck('d2', 'Algebra')],
    );

    expect(result.map((c) => c.deckName), ['Algebra', 'Zoology']);
  });

  test('drops run-through entries whose deck is not in the deck list', () {
    final result = deckCompletions(
      {'d1': 1, 'ghost': 9},
      [_deck('d1', 'Anatomy')],
    );

    expect(result.map((c) => c.deckId), ['d1']);
  });

  test('empty run-throughs yields an empty list', () {
    expect(deckCompletions({}, [_deck('d1', 'Anatomy')]), isEmpty);
  });
}
