import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';

FlashCard _card({
  String front = 'Front',
  String back = 'Back',
  List<String> keywords = const [],
  bool isConcept = false,
}) => FlashCard(
  id: 'card-1',
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: keywords,
  isConcept: isConcept,
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
        availableModes([
          _card(),
          _card(keywords: ['Paris'], front: 'Paris x'),
        ]),
        {StudyMode.flip, StudyMode.cloze},
      );
    });

    test('only blank keywords do not add Cloze', () {
      expect(
        availableModes([
          _card(keywords: ['   ']),
        ]),
        {StudyMode.flip},
      );
    });

    test('a concept card adds Feynman', () {
      expect(availableModes([_card(isConcept: true)]), {
        StudyMode.flip,
        StudyMode.feynman,
      });
    });

    test('a multi-line back alone does not add Feynman', () {
      expect(availableModes([_card(back: 'one\ntwo\nthree')]), {
        StudyMode.flip,
      });
    });

    test('a deck can offer every mode', () {
      expect(
        availableModes([
          _card(keywords: ['Paris'], front: 'Paris'),
          _card(isConcept: true),
        ]),
        {StudyMode.flip, StudyMode.cloze, StudyMode.feynman},
      );
    });
  });

  test('every mode has a label', () {
    for (final mode in StudyMode.values) {
      expect(mode.label, isNotEmpty);
    }
  });

  test('List mode is gone', () {
    expect(StudyMode.values, [
      StudyMode.flip,
      StudyMode.cloze,
      StudyMode.feynman,
    ]);
  });
}
