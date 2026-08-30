import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/levenshtein.dart';

void main() {
  group('levenshtein', () {
    test('is zero for equal strings', () {
      expect(levenshtein('mitochondria', 'mitochondria'), 0);
    });

    test('counts single-edit distances', () {
      expect(levenshtein('cell', 'cull'), 1); // substitution
      expect(levenshtein('cell', 'cells'), 1); // insertion
      expect(levenshtein('cells', 'cell'), 1); // deletion
    });

    test('handles an empty operand', () {
      expect(levenshtein('', 'abc'), 3);
      expect(levenshtein('abc', ''), 3);
    });
  });

  group('normalizeClozeAnswer', () {
    test('trims, lowercases, and strips edge punctuation and quotes', () {
      expect(normalizeClozeAnswer('  "Cell." '), 'cell');
      expect(normalizeClozeAnswer('(ATP)'), 'atp');
    });

    test('leaves internal punctuation and spacing alone', () {
      expect(normalizeClozeAnswer('spinal cord'), 'spinal cord');
      expect(normalizeClozeAnswer('non-coding'), 'non-coding');
    });
  });

  group('isClozeMatch', () {
    test('an exact match passes (case- and punctuation-insensitive)', () {
      expect(isClozeMatch('Paris', 'paris'), isTrue);
      expect(isClozeMatch('Paris', '  "paris." '), isTrue);
    });

    test('a short keyword tolerates one edit, not two', () {
      expect(isClozeMatch('cell', 'cel'), isTrue); // distance 1
      expect(isClozeMatch('cell', 'ce'), isFalse); // distance 2
    });

    test('a long keyword tolerates two edits', () {
      expect(isClozeMatch('mitochondria', 'mitochondria'), isTrue);
      expect(isClozeMatch('mitochondria', 'mitokondria'), isTrue); // distance 2
      expect(isClozeMatch('mitochondria', 'mtokondria'), isFalse); // distance 3
    });

    test('an empty answer never matches', () {
      expect(isClozeMatch('cell', ''), isFalse);
      expect(isClozeMatch('cell', '   '), isFalse);
    });
  });
}
