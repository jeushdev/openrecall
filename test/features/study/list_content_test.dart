import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/list_content.dart';

void main() {
  group('contentLines', () {
    test('splits on newlines, trims, and drops blank lines', () {
      expect(contentLines('  one \n\n  two  \n'), ['one', 'two']);
    });

    test('strips a leading "- " bullet marker', () {
      expect(contentLines('- Legislative\n- Executive\n- Judicial'), [
        'Legislative',
        'Executive',
        'Judicial',
      ]);
    });

    test('strips "* " and "• " markers too', () {
      expect(contentLines('* Solid\n• Liquid'), ['Solid', 'Liquid']);
    });

    test('leaves a dash that is not a bullet marker alone', () {
      expect(contentLines('non-bullet text\n-nospace'), [
        'non-bullet text',
        '-nospace',
      ]);
    });

    test('only the first marker is removed', () {
      expect(contentLines('- - nested'), ['- nested']);
    });
  });
}
