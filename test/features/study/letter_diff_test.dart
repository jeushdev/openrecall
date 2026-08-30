import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/letter_diff.dart';

void main() {
  group('letterDiff', () {
    test('a clean match is one match run', () {
      expect(letterDiff('cell', 'cell'), const [
        DiffSegment('cell', DiffOp.match),
      ]);
    });

    test('a wrong letter is flagged, the rest matches', () {
      expect(letterDiff('cell', 'ceil'), const [
        DiffSegment('ce', DiffOp.match),
        DiffSegment('i', DiffOp.wrong),
        DiffSegment('l', DiffOp.match),
      ]);
    });

    test('a missing letter carries the expected character', () {
      expect(letterDiff('cell', 'cel'), const [
        DiffSegment('ce', DiffOp.match),
        DiffSegment('l', DiffOp.missing),
        DiffSegment('l', DiffOp.match),
      ]);
    });

    test('an extra letter is struck from the attempt', () {
      expect(letterDiff('cell', 'cells'), const [
        DiffSegment('cell', DiffOp.match),
        DiffSegment('s', DiffOp.extra),
      ]);
    });

    test('normalises both sides before aligning', () {
      expect(letterDiff('Paris', ' paris '), const [
        DiffSegment('paris', DiffOp.match),
      ]);
    });
  });
}
