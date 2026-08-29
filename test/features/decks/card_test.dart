import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';

void main() {
  Map<String, dynamic> row({String? keyword, int mastery = 0, int fails = 0}) =>
      {
        'id': 'card-1',
        'deck_id': 'deck-1',
        'front': 'Capital of France',
        'back': 'Paris',
        'keyword': keyword,
        'mastery_level': mastery,
        'fail_count': fails,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-02T00:00:00Z',
      };

  group('FlashCard.fromJson', () {
    test('maps the snake_case columns onto the model', () {
      final card = FlashCard.fromJson(row(keyword: 'Paris', mastery: 3, fails: 2));

      expect(card.id, 'card-1');
      expect(card.deckId, 'deck-1');
      expect(card.front, 'Capital of France');
      expect(card.back, 'Paris');
      expect(card.keyword, 'Paris');
      expect(card.masteryLevel, 3);
      expect(card.failCount, 2);
      expect(card.updatedAt, DateTime.utc(2026, 8, 2));
    });

    test('a null keyword stays null', () {
      expect(FlashCard.fromJson(row()).keyword, isNull);
    });
  });

  group('FlashCard equality', () {
    test('two cards with the same fields are equal', () {
      expect(FlashCard.fromJson(row()), FlashCard.fromJson(row()));
    });

    test('cards differing by a field are not equal', () {
      expect(FlashCard.fromJson(row(mastery: 1)), isNot(FlashCard.fromJson(row())));
    });
  });

  test('masteredLevel is 4', () {
    expect(masteredLevel, 4);
  });

  group('CardMasteryState.fromJson', () {
    test('maps the three columns the session engine guards on', () {
      final state = CardMasteryState.fromJson({
        'mastery_level': 2,
        'fail_count': 5,
        'updated_at': '2026-08-02T00:00:00Z',
      });
      expect(state.masteryLevel, 2);
      expect(state.failCount, 5);
      expect(state.updatedAt, DateTime.utc(2026, 8, 2));
    });
  });
}
