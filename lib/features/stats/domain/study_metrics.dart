import 'package:flutter/foundation.dart';

import 'completed_session.dart';
import 'streak.dart';

/// The single longest span, in wall-clock time, that any one session is allowed
/// to contribute to "total study time". Sessions are resumable, so a session
/// left open for days would otherwise dwarf every real study period; anything
/// past two hours is treated as "walked away and came back".
const Duration maxCountedSessionDuration = Duration(hours: 2);

/// Everything the Profile tab's "Study habits" block shows (offline-and-ux
/// milestone D). A pure derivation of the user's completed-session history — see
/// [buildStudyMetrics]. "Current streak" is also shown, computed here so the one
/// history fetch serves every tile.
@immutable
class StudyMetrics {
  const StudyMetrics({
    required this.currentStreak,
    required this.longestStreak,
    required this.sessionsCompleted,
    required this.totalCardsReviewed,
    required this.totalStudyTime,
    required this.thisWeekSessions,
    required this.thisWeekCards,
    required this.thisWeekStudyTime,
  });

  final int currentStreak;
  final int longestStreak;
  final int sessionsCompleted;
  final int totalCardsReviewed;
  final Duration totalStudyTime;
  final int thisWeekSessions;
  final int thisWeekCards;
  final Duration thisWeekStudyTime;

  static const empty = StudyMetrics(
    currentStreak: 0,
    longestStreak: 0,
    sessionsCompleted: 0,
    totalCardsReviewed: 0,
    totalStudyTime: Duration.zero,
    thisWeekSessions: 0,
    thisWeekCards: 0,
    thisWeekStudyTime: Duration.zero,
  );
}

/// Folds a list of [CompletedSession]s into the Profile metrics.
///
/// All calendar reasoning is in the **device-local timezone**. The current week
/// starts on the most recent Monday at 00:00 local (the app has no other
/// week-start convention). A session belongs to the week its `started_at` falls
/// in — the same timestamp the streaks are built from. [now] is injectable for
/// tests and defaults to [DateTime.now].
StudyMetrics buildStudyMetrics({
  required List<CompletedSession> sessions,
  DateTime? now,
}) {
  if (sessions.isEmpty) return StudyMetrics.empty;

  final current = now ?? DateTime.now();
  final weekStart = _mostRecentMonday(current);

  var totalCards = 0;
  var totalTime = Duration.zero;
  var weekSessions = 0;
  var weekCards = 0;
  var weekTime = Duration.zero;

  for (final s in sessions) {
    final cards = s.cardsReviewed ?? 0;
    final duration = _countedDuration(s);
    totalCards += cards;
    totalTime += duration;

    if (!s.startedAt.toLocal().isBefore(weekStart)) {
      weekSessions++;
      weekCards += cards;
      weekTime += duration;
    }
  }

  final starts = sessions.map((s) => s.startedAt);

  return StudyMetrics(
    currentStreak: currentStreak(starts, now: current),
    longestStreak: longestStreak(starts),
    sessionsCompleted: sessions.length,
    totalCardsReviewed: totalCards,
    totalStudyTime: totalTime,
    thisWeekSessions: weekSessions,
    thisWeekCards: weekCards,
    thisWeekStudyTime: weekTime,
  );
}

/// The session's wall-clock length, clamped to [maxCountedSessionDuration]. Zero
/// when `completed_at` is missing or not after `started_at`.
Duration _countedDuration(CompletedSession s) {
  final end = s.completedAt;
  if (end == null) return Duration.zero;
  final raw = end.difference(s.startedAt);
  if (raw <= Duration.zero) return Duration.zero;
  return raw > maxCountedSessionDuration ? maxCountedSessionDuration : raw;
}

/// Midnight, local time, on the most recent Monday on or before [current].
///
/// Built by day-number arithmetic inside the `DateTime` constructor (which
/// normalises an out-of-range day into the previous month) so the result is
/// always a real local midnight — no `Duration` subtraction that a DST change
/// could shift by an hour.
DateTime _mostRecentMonday(DateTime current) {
  final local = current.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day - (local.weekday - DateTime.monday),
  );
}
