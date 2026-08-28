import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';

FlashCard _card({
  String front = 'Front',
  String back = 'Back',
  String? keyword,
}) =>
    FlashCard(
      id: 'card-1',
      deckId: 'deck-1',
      front: front,
      back: back,
      keyword: keyword,
      masteryLevel: 0,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('availableModes', () {
    test('an empty deck still offers Flip', () {
      expect(availableModes(const []), {StudyMode.flip});
    });

    test('plain front/back cards offer only Flip', () {
      expect(availableModes([_card()]), {StudyMode.flip});
    });

    test('a keyword on any card adds Cloze', () {
      expect(
        availableModes([_card(), _card(keyword: 'Paris', front: 'Paris x')]),
        {StudyMode.flip, StudyMode.cloze},
      );
    });

    test('a blank keyword does not add Cloze', () {
      expect(availableModes([_card(keyword: '   ')]), {StudyMode.flip});
    });

    test('a multi-line back adds List and Feynman together', () {
      expect(
        availableModes([_card(back: 'one\ntwo\nthree')]),
        {StudyMode.flip, StudyMode.list, StudyMode.feynman},
      );
    });

    test('a multi-line front counts the same as a multi-line back', () {
      expect(
        availableModes([_card(front: 'a\nb')]),
        {StudyMode.flip, StudyMode.list, StudyMode.feynman},
      );
    });

    test('a trailing newline alone is not multi-line', () {
      expect(availableModes([_card(back: 'Paris\n')]), {StudyMode.flip});
    });

    test('a deck can offer every mode', () {
      expect(
        availableModes([
          _card(keyword: 'Paris', front: 'Paris'),
          _card(back: 'a\nb'),
        ]),
        {StudyMode.flip, StudyMode.cloze, StudyMode.list, StudyMode.feynman},
      );
    });
  });

  test('every mode has a label', () {
    for (final mode in StudyMode.values) {
      expect(mode.label, isNotEmpty);
    }
  });
}
