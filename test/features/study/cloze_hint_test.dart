import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/cloze_hint.dart';

void main() {
  test('repeated presses reveal one grapheme and cap at the answer', () {
    var hint = ClozeHint.initial('Cat');
    expect(hint.maskedAnswer, isNull);

    hint = hint.revealNext();
    expect(hint.maskedAnswer, 'C••');
    hint = hint.revealNext().revealNext().revealNext();
    expect(hint.maskedAnswer, 'Cat');
    expect(hint.canReveal, isFalse);
    expect(identical(hint.revealNext(), hint), isTrue);
  });

  test('spaces and punctuation are literal without consuming presses', () {
    final hint = ClozeHint.initial('New  York!').revealNext();
    expect(hint.maskedAnswer, 'N••  ••••!');
    expect(hint.revealedCount, 1);
  });

  test('digits and non-punctuation symbols consume presses', () {
    var hint = ClozeHint.initial(r'2+2=$4').revealNext();
    expect(hint.maskedAnswer, '2•••••');
    hint = hint.revealNext();
    expect(hint.maskedAnswer, '2+••••');
  });

  test('composed Unicode is revealed as one user-perceived character', () {
    final hint = ClozeHint.initial('élan').revealNext();
    expect(hint.maskedAnswer, 'é•••');
    expect(hint.revealedCount, 1);
  });

  test('punctuation-only answer has one effective press', () {
    var hint = ClozeHint.initial('...?!');
    expect(hint.canReveal, isTrue);
    hint = hint.revealNext();
    expect(hint.maskedAnswer, '...?!');
    expect(hint.canReveal, isFalse);
  });
}
