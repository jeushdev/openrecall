import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/decks/domain/deck.dart';

void main() {
  Map<String, dynamic> row({
    List<int> masteryLevels = const [],
    String? lastStudiedAt,
  }) =>
      {
        'id': 'deck-1',
        'name': 'Biology',
        'last_studied_at': lastStudiedAt,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-01T00:00:00Z',
        'cards': [
          for (final m in masteryLevels) {'mastery_level': m},
        ],
      };

  group('DeckSummary.fromJson', () {
    test('a deck with no cards is 0% mastery, 0 due, 0 total', () {
      final summary = DeckSummary.fromJson(row());

      expect(summary.totalCards, 0);
      expect(summary.dueCards, 0);
      expect(summary.masteryPercent, 0);
    });

    test('all-unfamiliar cards are 0% and every card is due', () {
      final summary = DeckSummary.fromJson(row(masteryLevels: [0, 0, 0, 0]));

      expect(summary.totalCards, 4);
      expect(summary.dueCards, 4);
      expect(summary.masteryPercent, 0);
    });

    test('all-mastered cards are 100% with nothing due', () {
      final summary = DeckSummary.fromJson(row(masteryLevels: [4, 4]));

      expect(summary.masteryPercent, 100);
      expect(summary.dueCards, 0);
    });

    test('mastery percent is the rounded average scaled from 0-4 to 0-100', () {
      // levels 1 and 4 -> mean 2.5 / 4 = 62.5% -> rounds to 63
      final summary = DeckSummary.fromJson(row(masteryLevels: [1, 4]));

      expect(summary.masteryPercent, 63);
      expect(summary.dueCards, 1);
    });

    test('carries the deck identity fields through', () {
      final summary = DeckSummary.fromJson(
        row(masteryLevels: [2], lastStudiedAt: '2026-08-20T12:00:00Z'),
      );

      expect(summary.id, 'deck-1');
      expect(summary.name, 'Biology');
      expect(summary.lastStudiedAt, DateTime.utc(2026, 8, 20, 12));
    });

    test('a null last_studied_at parses to null', () {
      expect(DeckSummary.fromJson(row()).lastStudiedAt, isNull);
    });
  });
}
