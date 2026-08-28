import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/keyword_validator.dart';

void main() {
  group('keywordError', () {
    test('an empty keyword is allowed (keyword is optional)', () {
      expect(keywordError('', front: 'anything', back: 'anything'), isNull);
    });

    test('a whitespace-only keyword is allowed', () {
      expect(keywordError('   ', front: 'a', back: 'b'), isNull);
    });

    test('a keyword that is a substring of the front is accepted', () {
      expect(
        keywordError('mitochondria',
            front: 'The mitochondria does what?', back: 'Makes ATP'),
        isNull,
      );
    });

    test('a keyword that is a substring of the back is accepted', () {
      expect(
        keywordError('Paris',
            front: 'Capital of France', back: 'The capital is Paris'),
        isNull,
      );
    });

    test('a keyword absent from both sides returns a message', () {
      final error = keywordError('Berlin',
          front: 'Capital of France', back: 'The capital is Paris');

      expect(error, isNotNull);
      expect(error, contains('front or back'));
    });

    test('matching is case-sensitive', () {
      expect(
        keywordError('paris',
            front: 'Capital of France', back: 'The capital is Paris'),
        isNotNull,
      );
    });
  });
}
