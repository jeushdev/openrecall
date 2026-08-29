import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';

void main() {
  group('FlipRating', () {
    test('there are five ratings, 0..4', () {
      expect(FlipRating.values.map((r) => r.level), [0, 1, 2, 3, 4]);
    });

    test('the level is the enum index (Flip translation is the identity)', () {
      expect(FlipRating.unfamiliar.level, 0);
      expect(FlipRating.mastered.level, 4);
    });

    test('only Mastered counts as mastered; everything below is a fail', () {
      expect(FlipRating.unfamiliar.isFail, isTrue);
      expect(FlipRating.forgotten.isFail, isTrue);
      expect(FlipRating.okay.isFail, isTrue);
      expect(FlipRating.familiar.isFail, isTrue);
      expect(FlipRating.mastered.isFail, isFalse);
    });

    test('Mastered maps to masteredLevel', () {
      expect(FlipRating.mastered.level, masteredLevel);
      expect(FlipRating.mastered.isMastered, isTrue);
    });

    test('every rating has a non-empty label', () {
      for (final rating in FlipRating.values) {
        expect(rating.label, isNotEmpty);
      }
    });
  });
}
