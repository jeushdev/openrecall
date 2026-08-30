import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/cloze_outcome.dart';
import 'package:open_recall/features/study/domain/flip_rating.dart';

void main() {
  group('ClozeOutcome.masteryLevel', () {
    test('a first-try correct answer maps to Mastered', () {
      expect(ClozeOutcome.correct.masteryLevel, FlipRating.mastered.level);
      expect(ClozeOutcome.correct.masteryLevel, 4);
    });

    test('an overridden answer maps to Familiar', () {
      expect(ClozeOutcome.overridden.masteryLevel, FlipRating.familiar.level);
      expect(ClozeOutcome.overridden.masteryLevel, 3);
    });

    test('a missed answer maps to Forgotten', () {
      expect(ClozeOutcome.missed.masteryLevel, FlipRating.forgotten.level);
      expect(ClozeOutcome.missed.masteryLevel, 1);
    });
  });
}
