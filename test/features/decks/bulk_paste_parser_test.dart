import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/bulk_paste_parser.dart';

void main() {
  group('parseBulkPaste', () {
    test('parses a plain FRONT | BACK line', () {
      final result = parseBulkPaste('Capital of France | Paris');

      expect(result.lines, hasLength(1));
      final card = result.lines.single as ParsedCard;
      expect(card.lineNumber, 1);
      expect(card.front, 'Capital of France');
      expect(card.back, 'Paris');
      expect(card.keywords, isEmpty);
      expect(card.isConcept, isFalse);
    });

    test('trims whitespace around front and back', () {
      final card =
          parseBulkPaste('  Capital of France   |   Paris  ').lines.single
              as ParsedCard;

      expect(card.front, 'Capital of France');
      expect(card.back, 'Paris');
    });

    test('skips blank and whitespace-only lines without counting them', () {
      final result = parseBulkPaste('\nA | B\n   \nC | D\n');

      expect(result.lines, hasLength(2));
      expect((result.lines[0] as ParsedCard).front, 'A');
      expect((result.lines[1] as ParsedCard).front, 'C');
      expect((result.lines[1] as ParsedCard).lineNumber, 4);
    });

    test('a line with no pipe is a failure', () {
      final failure = parseBulkPaste('no separator here').lines.single
          as ParseFailure;

      expect(failure.lineNumber, 1);
      expect(failure.raw, 'no separator here');
      expect(failure.reason, contains('|'));
    });

    test('an empty front is a failure', () {
      final failure =
          parseBulkPaste('   | Paris').lines.single as ParseFailure;

      expect(failure.reason.toLowerCase(), contains('front'));
    });

    test('an empty back is a failure', () {
      final failure =
          parseBulkPaste('Capital of France |   ').lines.single as ParseFailure;

      expect(failure.reason.toLowerCase(), contains('back'));
    });

    test('splits on the first pipe only, keeping later pipes in the back', () {
      final card =
          parseBulkPaste('Boolean ops | a | b | c').lines.single as ParsedCard;

      expect(card.front, 'Boolean ops');
      expect(card.back, 'a | b | c');
    });

    test('extracts a {{keyword}} from the back and strips the braces', () {
      final card = parseBulkPaste('Capital of France | The capital is {{Paris}}')
          .lines
          .single as ParsedCard;

      expect(card.back, 'The capital is Paris');
      expect(card.keywords, ['Paris']);
    });

    test('extracts a {{keyword}} from the front and strips the braces', () {
      final card = parseBulkPaste('The {{mitochondria}} does what? | Makes ATP')
          .lines
          .single as ParsedCard;

      expect(card.front, 'The mitochondria does what?');
      expect(card.keywords, ['mitochondria']);
    });

    test('trims whitespace inside the braces', () {
      final card = parseBulkPaste('Q | a {{ Paris }} b').lines.single
          as ParsedCard;

      expect(card.keywords, ['Paris']);
      expect(card.back, 'a Paris b');
    });

    test('collects multiple {{ }} markers on one side into keywords', () {
      final card = parseBulkPaste('{{mitosis}} vs {{meiosis}} | different')
          .lines
          .single as ParsedCard;

      expect(card.front, 'mitosis vs meiosis');
      expect(card.keywords, ['mitosis', 'meiosis']);
    });

    test('collects markers from both sides, front first then back', () {
      final card =
          parseBulkPaste('The {{powerhouse}} of the cell | makes {{ATP}}')
              .lines
              .single as ParsedCard;

      expect(card.front, 'The powerhouse of the cell');
      expect(card.back, 'makes ATP');
      expect(card.keywords, ['powerhouse', 'ATP']);
    });

    test('counts ready and failed lines', () {
      final result = parseBulkPaste('A | B\nbroken line\nC | {{D}}');

      expect(result.readyCount, 2);
      expect(result.failureCount, 1);
    });
  });
}
