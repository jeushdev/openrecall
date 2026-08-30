import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/bulk_paste_parser.dart';

void main() {
  group('parseBulkPaste — one-line blocks', () {
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

    test('splits on the first pipe only, keeping later pipes in the back', () {
      final card =
          parseBulkPaste('Boolean ops | a | b | c').lines.single as ParsedCard;

      expect(card.front, 'Boolean ops');
      expect(card.back, 'a | b | c');
    });

    test('a one-line block with no pipe is a failure with a reason', () {
      final failure = parseBulkPaste('no separator here').lines.single
          as ParseFailure;

      expect(failure.lineNumber, 1);
      expect(failure.raw, 'no separator here');
      expect(failure.reason.toLowerCase(), contains('back'));
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
  });

  group('parseBulkPaste — blocks', () {
    test('a blank line separates two blocks; line numbers point at block starts',
        () {
      final result = parseBulkPaste('A | B\n\nC | D');

      expect(result.lines, hasLength(2));
      expect((result.lines[0] as ParsedCard).lineNumber, 1);
      expect((result.lines[1] as ParsedCard).lineNumber, 3);
      expect((result.lines[1] as ParsedCard).front, 'C');
    });

    test('runs of blank lines and leading/trailing blanks are ignored', () {
      final result = parseBulkPaste('\n\nA | B\n   \n\nC | D\n\n');

      expect(result.lines, hasLength(2));
      expect((result.lines[1] as ParsedCard).lineNumber, 6);
    });

    test('a multi-line block is one card: first line front, rest back', () {
      final card = parseBulkPaste(
        'What are the primary colors?\n'
        '- Red\n'
        '- Yellow\n'
        '- Blue',
      ).lines.single as ParsedCard;

      expect(card.front, 'What are the primary colors?');
      expect(card.back, '- Red\n- Yellow\n- Blue');
      expect(card.isConcept, isFalse);
    });

    test('bullet markers in the back are preserved verbatim', () {
      final card = parseBulkPaste('Q\n* one\n* two').lines.single as ParsedCard;

      expect(card.back, '* one\n* two');
    });

    test('consecutive pipe lines with no blank between them are ONE card', () {
      final result = parseBulkPaste('Q1 | A1\nQ2 | A2');

      expect(result.lines, hasLength(1));
      final card = result.lines.single as ParsedCard;
      expect(card.front, 'Q1 | A1');
      expect(card.back, 'Q2 | A2');
    });
  });

  group('parseBulkPaste — [concept]', () {
    test('a [concept] line sets isConcept and is stripped from the text', () {
      final card = parseBulkPaste(
        'Explain natural selection.\n'
        '[concept]\n'
        '- Individuals vary.\n'
        '- The fittest variants leave more offspring.',
      ).lines.single as ParsedCard;

      expect(card.isConcept, isTrue);
      expect(card.front, 'Explain natural selection.');
      expect(card.back,
          '- Individuals vary.\n- The fittest variants leave more offspring.');
    });

    test('the [concept] tag is case-insensitive and position-independent', () {
      final card = parseBulkPaste('Front\n[Concept]\nBack line').lines.single
          as ParsedCard;

      expect(card.isConcept, isTrue);
      expect(card.front, 'Front');
      expect(card.back, 'Back line');
    });

    test('a block that is only a [concept] tag is a failure', () {
      final failure =
          parseBulkPaste('[concept]').lines.single as ParseFailure;

      expect(failure.reason.toLowerCase(), contains('concept'));
    });

    test('a concept block with a front but no back is a failure', () {
      final failure =
          parseBulkPaste('Just a front\n[concept]').lines.single as ParseFailure;

      expect(failure.reason.toLowerCase(), contains('back'));
    });
  });

  group('parseBulkPaste — keywords', () {
    test('extracts a {{keyword}} from the back and strips the braces', () {
      final card = parseBulkPaste('Capital of France | The capital is {{Paris}}')
          .lines
          .single as ParsedCard;

      expect(card.back, 'The capital is Paris');
      expect(card.keywords, ['Paris']);
    });

    test('trims whitespace inside the braces', () {
      final card =
          parseBulkPaste('Q | a {{ Paris }} b').lines.single as ParsedCard;

      expect(card.keywords, ['Paris']);
      expect(card.back, 'a Paris b');
    });

    test('collects multiple markers across a block, front first then back', () {
      final card = parseBulkPaste(
        'The {{powerhouse}} of the cell\n'
        '- It makes {{ATP}}\n'
        '- Via {{respiration}}',
      ).lines.single as ParsedCard;

      expect(card.front, 'The powerhouse of the cell');
      expect(card.back, '- It makes ATP\n- Via respiration');
      expect(card.keywords, ['powerhouse', 'ATP', 'respiration']);
    });
  });

  group('parseBulkPaste — result counts', () {
    test('counts ready and failed blocks', () {
      final result = parseBulkPaste('A | B\n\nbroken block\n\nC | {{D}}');

      expect(result.readyCount, 2);
      expect(result.failureCount, 1);
    });
  });
}
