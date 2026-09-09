import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/study_metrics.dart';

void main() {
  // 2026-08-26 is a Wednesday; the current week runs from Monday 2026-08-24
  // 00:00 local time.
  final now = DateTime(2026, 8, 26, 12);

  CompletedSession session(
    DateTime startedAt, {
    DateTime? completedAt,
    int? cardsReviewed,
  }) => CompletedSession(
    startedAt: startedAt,
    completedAt: completedAt,
    cardsReviewed: cardsReviewed,
  );

  test('an empty history is all zeros', () {
    final m = buildStudyMetrics(sessions: const [], now: now);

    expect(m.sessionsCompleted, 0);
    expect(m.totalCardsReviewed, 0);
    expect(m.totalStudyTime, Duration.zero);
    expect(m.currentStreak, 0);
    expect(m.longestStreak, 0);
    expect(m.thisWeekSessions, 0);
    expect(m.thisWeekCards, 0);
    expect(m.thisWeekStudyTime, Duration.zero);
  });

  test(
    'lifetime totals sum every completed session, nulls counted as zero',
    () {
      final m = buildStudyMetrics(
        sessions: [
          session(DateTime(2026, 8, 26, 8), cardsReviewed: 7),
          session(DateTime(2026, 8, 20, 9), cardsReviewed: 10),
          session(DateTime(2026, 7, 1, 9), cardsReviewed: null),
        ],
        now: now,
      );

      expect(m.sessionsCompleted, 3);
      expect(m.totalCardsReviewed, 17);
    },
  );

  test('per-session study time is clamped to two hours', () {
    final m = buildStudyMetrics(
      sessions: [
        // 12h wall-clock span (a session resumed days later) -> clamped to 2h.
        session(
          DateTime(2026, 8, 26, 8),
          completedAt: DateTime(2026, 8, 26, 20),
        ),
        // 45 real minutes.
        session(
          DateTime(2026, 8, 20, 0, 30),
          completedAt: DateTime(2026, 8, 20, 1, 15),
        ),
      ],
      now: now,
    );

    expect(m.totalStudyTime, const Duration(hours: 2, minutes: 45));
  });

  test('a session with no completed_at is skipped from study time', () {
    final m = buildStudyMetrics(
      sessions: [
        session(DateTime(2026, 8, 26, 8), completedAt: null, cardsReviewed: 4),
      ],
      now: now,
    );

    expect(m.totalStudyTime, Duration.zero);
    expect(m.sessionsCompleted, 1);
    expect(m.totalCardsReviewed, 4);
  });

  test('this-week rollups respect the local Monday boundary', () {
    final m = buildStudyMetrics(
      sessions: [
        // Sunday 23:30 local — last week.
        session(
          DateTime(2026, 8, 23, 23, 30),
          completedAt: DateTime(2026, 8, 24, 0, 0),
          cardsReviewed: 5,
        ),
        // Monday 00:30 local — this week.
        session(
          DateTime(2026, 8, 24, 0, 30),
          completedAt: DateTime(2026, 8, 24, 1, 15),
          cardsReviewed: 10,
        ),
        // Wednesday — this week, 12h span clamped to 2h.
        session(
          DateTime(2026, 8, 26, 8),
          completedAt: DateTime(2026, 8, 26, 20),
          cardsReviewed: 7,
        ),
        // Weeks ago.
        session(
          DateTime(2026, 7, 1, 10),
          completedAt: DateTime(2026, 7, 1, 10, 40),
          cardsReviewed: 3,
        ),
      ],
      now: now,
    );

    expect(m.thisWeekSessions, 2);
    expect(m.thisWeekCards, 17);
    expect(m.thisWeekStudyTime, const Duration(hours: 2, minutes: 45));
  });

  test('streaks are derived from the session start days', () {
    final m = buildStudyMetrics(
      sessions: [
        session(DateTime(2026, 8, 10, 9)),
        session(DateTime(2026, 8, 11, 9)),
        session(DateTime(2026, 8, 12, 9)),
        session(DateTime(2026, 8, 25, 9)),
        session(DateTime(2026, 8, 26, 9)),
      ],
      now: now,
    );

    // Longest run is the Aug 10-12 stretch; the current run (Aug 25-26, with
    // "today" being the 26th) is two days.
    expect(m.longestStreak, 3);
    expect(m.currentStreak, 2);
  });
}
