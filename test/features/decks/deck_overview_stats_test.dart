import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/domain/deck_overview_stats.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';

FlashCard _card({
  String id = 'card',
  String front = 'Front',
  String back = 'Back',
  String? keyword,
  int mastery = 0,
  int fails = 0,
}) =>
    FlashCard(
      id: id,
      deckId: 'deck-1',
      front: front,
      back: back,
      keyword: keyword,
      masteryLevel: mastery,
      failCount: fails,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  group('DeckOverviewStats.fromCards', () {
    test('an empty deck is empty, 0%, nothing due, Flip only', () {
      final stats = DeckOverviewStats.fromCards(const []);

      expect(stats.isEmpty, isTrue);
      expect(stats.totalCards, 0);
      expect(stats.dueCards, 0);
      expect(stats.masteryPercent, 0);
      expect(stats.allCaughtUp, isFalse);
      expect(stats.modes, {StudyMode.flip});
    });

    test('counts totals, due, keyword and multi-line cards', () {
      final stats = DeckOverviewStats.fromCards([
        _card(id: 'a', keyword: 'k', front: 'k', mastery: 4),
        _card(id: 'b', back: 'one\ntwo'),
        _card(id: 'c'),
      ]);

      expect(stats.totalCards, 3);
      expect(stats.dueCards, 2);
      expect(stats.withKeyword, 1);
      expect(stats.multiLine, 1);
      expect(stats.modes, {
        StudyMode.flip,
        StudyMode.cloze,
        StudyMode.list,
        StudyMode.feynman,
      });
    });

    test('mastery percent matches the shared helper', () {
      final stats = DeckOverviewStats.fromCards([
        _card(id: 'a', mastery: 1),
        _card(id: 'b', mastery: 4),
      ]);

      expect(stats.masteryPercent, masteryPercentFromLevels(const [1, 4]));
      expect(stats.masteryPercent, 63);
    });

    test('all-caught-up when cards exist but none are due', () {
      final stats = DeckOverviewStats.fromCards([
        _card(id: 'a', mastery: 4),
        _card(id: 'b', mastery: 4),
      ]);

      expect(stats.isEmpty, isFalse);
      expect(stats.allCaughtUp, isTrue);
    });

    group('troublemakers', () {
      test('excludes cards that have never failed', () {
        final stats = DeckOverviewStats.fromCards([_card(fails: 0)]);
        expect(stats.troublemakers, isEmpty);
      });

      test('sorted by fail_count descending', () {
        final stats = DeckOverviewStats.fromCards([
          _card(id: 'a', fails: 2),
          _card(id: 'b', fails: 9),
          _card(id: 'c', fails: 5),
        ]);

        expect(
          stats.troublemakers.map((c) => c.id),
          ['b', 'c', 'a'],
        );
      });

      test('capped at five', () {
        final stats = DeckOverviewStats.fromCards([
          for (var i = 0; i < 8; i++) _card(id: 'c$i', fails: i + 1),
        ]);

        expect(stats.troublemakers, hasLength(5));
        expect(stats.troublemakers.first.failCount, 8);
      });
    });
  });
}
