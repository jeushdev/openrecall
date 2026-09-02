import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/daily_activity.dart';

CompletedSession _session(DateTime completedAt, {DateTime? startedAt}) =>
    CompletedSession(
      startedAt: startedAt ?? completedAt,
      completedAt: completedAt,
      cardsReviewed: 5,
    );

void main() {
  group('buildDailyActivityCounts', () {
    test('groups sessions by local calendar day', () {
      final counts = buildDailyActivityCounts([
        _session(DateTime(2026, 8, 20, 9)),
        _session(DateTime(2026, 8, 20, 21)),
        _session(DateTime(2026, 8, 18, 12)),
      ]);

      expect(counts[DateTime(2026, 8, 20)], 2);
      expect(counts[DateTime(2026, 8, 18)], 1);
      expect(counts.containsKey(DateTime(2026, 8, 19)), isFalse);
    });

    test('falls back to startedAt when completedAt is null', () {
      final counts = buildDailyActivityCounts([
        CompletedSession(
          startedAt: DateTime(2026, 7, 4, 8),
          completedAt: null,
          cardsReviewed: null,
        ),
      ]);

      expect(counts[DateTime(2026, 7, 4)], 1);
    });

    test('is empty for no sessions', () {
      expect(buildDailyActivityCounts(const []), isEmpty);
    });
  });

  group('heatLevel', () {
    test('0 for an empty day, then ramps and caps at maxHeatLevel', () {
      expect(heatLevel(0), 0);
      expect(heatLevel(1), 1);
      expect(heatLevel(3), 3);
      expect(heatLevel(4), maxHeatLevel);
      expect(heatLevel(9), maxHeatLevel);
    });
  });
}
