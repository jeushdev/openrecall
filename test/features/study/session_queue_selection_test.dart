import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/study/domain/session_queue_selection.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

FlashCard _card({
  required String id,
  String front = 'Front',
  String back = 'Back',
  List<String> keywords = const [],
  bool isConcept = false,
  int mastery = 0,
}) => FlashCard(
  id: id,
  deckId: 'deck-1',
  front: front,
  back: back,
  keywords: keywords,
  isConcept: isConcept,
  masteryLevel: mastery,
  failCount: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('selectSessionCards — CardScope.due (V1 behaviour)', () {
    test('drops cards that are already Mastered', () {
      final cards = [
        _card(id: 'a', mastery: 4),
        _card(id: 'b', mastery: 2),
        _card(id: 'c', mastery: 0),
      ];
      final picked = selectSessionCards(
        cards: cards,
        mode: StudyMode.flip,
        cap: null,
        cardScope: CardScope.due,
      );
      expect(picked.map((c) => c.id), ['b', 'c']);
    });

    test('Flip applies no structural filter', () {
      final cards = [_card(id: 'a'), _card(id: 'b')];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.due,
        ).length,
        2,
      );
    });

    test('Cloze keeps only cards with a keyword', () {
      final cards = [
        _card(id: 'a', keywords: ['Paris']),
        _card(id: 'b'),
        _card(id: 'c', keywords: ['  ']),
      ];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.cloze,
          cap: null,
          cardScope: CardScope.due,
        ).map((c) => c.id),
        ['a'],
      );
    });

    test('Feynman keeps only concept-flagged cards', () {
      final cards = [
        _card(id: 'a', isConcept: true),
        _card(id: 'b', back: 'one\ntwo'),
      ];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.feynman,
          cap: null,
          cardScope: CardScope.due,
        ).map((c) => c.id),
        ['a'],
      );
    });

    test('the cap applies AFTER the due and mode filters', () {
      final cards = [
        _card(id: 'm1', mastery: 4),
        _card(id: 'a'),
        _card(id: 'm2', mastery: 4),
        _card(id: 'b'),
        _card(id: 'c'),
        _card(id: 'd'),
        _card(id: 'e'),
      ];
      final picked = selectSessionCards(
        cards: cards,
        mode: StudyMode.flip,
        cap: 3,
        cardScope: CardScope.due,
      );
      expect(picked.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('a null cap keeps every filtered card', () {
      final cards = [_card(id: 'a'), _card(id: 'b'), _card(id: 'c')];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.due,
        ).length,
        3,
      );
    });

    test('a cap larger than the pool keeps every filtered card', () {
      final cards = [_card(id: 'a'), _card(id: 'b')];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: 10,
          cardScope: CardScope.due,
        ).length,
        2,
      );
    });

    test('creation order is preserved', () {
      final cards = [_card(id: 'c'), _card(id: 'a'), _card(id: 'b')];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.due,
        ).map((c) => c.id),
        ['c', 'a', 'b'],
      );
    });

    test('an all-Mastered deck yields an empty queue', () {
      final cards = [_card(id: 'a', mastery: 4), _card(id: 'b', mastery: 4)];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.due,
        ),
        isEmpty,
      );
    });
  });

  group('selectSessionCards — CardScope.all', () {
    test('keeps already-Mastered cards in the queue', () {
      final cards = [
        _card(id: 'a', mastery: 4),
        _card(id: 'b', mastery: 2),
        _card(id: 'c', mastery: 0),
      ];
      final picked = selectSessionCards(
        cards: cards,
        mode: StudyMode.flip,
        cap: null,
        cardScope: CardScope.all,
      );
      expect(picked.map((c) => c.id), ['a', 'b', 'c']);
    });

    test('still applies the mode filter', () {
      final cards = [
        _card(id: 'a', keywords: ['Paris']),
        _card(id: 'b'),
        _card(id: 'm', keywords: ['Rome'], mastery: 4),
      ];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.cloze,
          cap: null,
          cardScope: CardScope.all,
        ).map((c) => c.id),
        ['a', 'm'],
      );
    });

    test('still applies the cap, after the mode filter', () {
      final cards = [
        _card(id: 'm1', mastery: 4),
        _card(id: 'a'),
        _card(id: 'm2', mastery: 4),
        _card(id: 'b'),
        _card(id: 'c'),
      ];
      final picked = selectSessionCards(
        cards: cards,
        mode: StudyMode.flip,
        cap: 3,
        cardScope: CardScope.all,
      );
      expect(picked.map((c) => c.id), ['m1', 'a', 'm2']);
    });

    test('an all-Mastered deck yields a non-empty queue', () {
      final cards = [_card(id: 'a', mastery: 4), _card(id: 'b', mastery: 4)];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.all,
        ).map((c) => c.id),
        ['a', 'b'],
      );
    });

    test('creation order is preserved', () {
      final cards = [
        _card(id: 'c', mastery: 4),
        _card(id: 'a'),
        _card(id: 'b', mastery: 4),
      ];
      expect(
        selectSessionCards(
          cards: cards,
          mode: StudyMode.flip,
          cap: null,
          cardScope: CardScope.all,
        ).map((c) => c.id),
        ['c', 'a', 'b'],
      );
    });
  });

  group('seedsFrom', () {
    test('assigns sparse positions in steps of 1000, starting at 1000', () {
      final seeds = seedsFrom([_card(id: 'a'), _card(id: 'b'), _card(id: 'c')]);
      expect(seeds.map((s) => s.cardId), ['a', 'b', 'c']);
      expect(seeds.map((s) => s.position), [1000, 2000, 3000]);
    });

    test('an empty list seeds nothing', () {
      expect(seedsFrom(const []), isEmpty);
    });
  });
}
