import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';

void main() {
  Map<String, dynamic> row({
    Object? keywords,
    Object? isConcept,
    int mastery = 0,
    int fails = 0,
  }) =>
      {
        'id': 'card-1',
        'deck_id': 'deck-1',
        'front': 'Capital of France',
        'back': 'Paris',
        'keywords': ?keywords,
        'is_concept': ?isConcept,
        'mastery_level': mastery,
        'fail_count': fails,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-02T00:00:00Z',
      };

  group('FlashCard.fromJson', () {
    test('maps the snake_case columns onto the model', () {
      final card = FlashCard.fromJson(row(
        keywords: ['Paris', 'France'],
        isConcept: true,
        mastery: 3,
        fails: 2,
      ));

      expect(card.id, 'card-1');
      expect(card.deckId, 'deck-1');
      expect(card.front, 'Capital of France');
      expect(card.back, 'Paris');
      expect(card.keywords, ['Paris', 'France']);
      expect(card.isConcept, isTrue);
      expect(card.masteryLevel, 3);
      expect(card.failCount, 2);
      expect(card.updatedAt, DateTime.utc(2026, 8, 2));
    });

    test('a missing keywords column becomes an empty list', () {
      expect(FlashCard.fromJson(row()).keywords, isEmpty);
    });

    test('a missing is_concept column defaults to false', () {
      expect(FlashCard.fromJson(row()).isConcept, isFalse);
    });
  });

  group('FlashCard equality', () {
    test('two cards with the same fields are equal', () {
      expect(FlashCard.fromJson(row()), FlashCard.fromJson(row()));
    });

    test('cards differing by a field are not equal', () {
      expect(FlashCard.fromJson(row(mastery: 1)), isNot(FlashCard.fromJson(row())));
    });

    test('cards differing only by keywords are not equal', () {
      expect(
        FlashCard.fromJson(row(keywords: ['Paris'])),
        isNot(FlashCard.fromJson(row(keywords: ['France']))),
      );
    });

    test('cards differing only by is_concept are not equal', () {
      expect(
        FlashCard.fromJson(row(isConcept: true)),
        isNot(FlashCard.fromJson(row(isConcept: false))),
      );
    });
  });

  test('masteredLevel is 4', () {
    expect(masteredLevel, 4);
  });

  group('masteryPercentFromLevelSum', () {
    test('0 cards is 0%', () {
      expect(masteryPercentFromLevelSum(0, 0), 0);
    });

    test('matches masteryPercentFromLevels for the same cards', () {
      expect(masteryPercentFromLevelSum(5, 2), masteryPercentFromLevels([1, 4]));
      expect(masteryPercentFromLevelSum(5, 2), 63);
    });

    test('all mastered is 100%', () {
      expect(masteryPercentFromLevelSum(16, 4), 100);
    });
  });

  group('masteryPercentFromLevels is unchanged', () {
    test('empty is 0%', () {
      expect(masteryPercentFromLevels(const []), 0);
    });

    test('rounds the scaled average', () {
      expect(masteryPercentFromLevels([1, 4]), 63);
      expect(masteryPercentFromLevels([0, 0, 4]), 33);
    });
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
