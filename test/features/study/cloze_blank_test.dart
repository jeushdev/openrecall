import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/cloze_blank.dart';

void main() {
  group('clozeSegments', () {
    test('numbers a blank per keyword occurrence, threading startIndex', () {
      final (front, next) = clozeSegments('A cell has a cell wall', ['cell']);
      final blanks = front.where((s) => s.isBlank).toList();
      expect(blanks.map((s) => s.blankIndex), [0, 1]);
      expect(next, 2);

      final (back, end) = clozeSegments('the cell membrane', [
        'cell',
      ], startIndex: next);
      expect(back.firstWhere((s) => s.isBlank).blankIndex, 2);
      expect(end, 3);
    });

    test('among overlapping keywords the longest wins at a position', () {
      final (segs, _) = clozeSegments('the cell membrane', [
        'cell',
        'cell membrane',
      ]);
      final blank = segs.firstWhere((s) => s.isBlank);
      expect(blank.text, 'cell membrane');
    });
  });

  group('clozeBlankAnswers', () {
    test('lists every blank answer, front occurrences then back', () {
      expect(
        clozeBlankAnswers('Paris is in France', 'France borders France', [
          'Paris',
          'France',
        ]),
        ['Paris', 'France', 'France', 'France'],
      );
    });

    test('preserves the cased substring the card actually blanked', () {
      expect(
        clozeBlankAnswers('The MITOCHONDRIA', 'a mitochondria', [
          'mitochondria',
        ]),
        ['MITOCHONDRIA', 'mitochondria'],
      );
    });

    test('is empty when no keyword appears in the card', () {
      expect(clozeBlankAnswers('front text', 'back text', ['absent']), isEmpty);
    });
  });
}
