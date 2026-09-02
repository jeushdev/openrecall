import 'completed_session.dart';

/// Per-calendar-day study totals for the History tab's calendar heatmap
/// (ui-spec-v4 §4). A genuinely new aggregation — no other provider computes
/// per-day counts.
///
/// Pure derivation of the completed-session history
/// (`completedSessionsProvider`). Days with no completed session are simply
/// absent from the map.

/// The highest heat bucket a day can land in — the heatmap shades a cell on a
/// 0–[maxHeatLevel] ramp.
const int maxHeatLevel = 4;

/// Groups [sessions] by the local calendar day they finished on (falling back
/// to [CompletedSession.startedAt] for a row with no `completedAt`) and counts
/// how many landed on each day. Keys are date-only `DateTime`s (midnight local).
Map<DateTime, int> buildDailyActivityCounts(
  Iterable<CompletedSession> sessions,
) {
  final counts = <DateTime, int>{};
  for (final session in sessions) {
    final at = session.completedAt ?? session.startedAt;
    final day = DateTime(at.year, at.month, at.day);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

/// Buckets a day's session [count] into a 0–[maxHeatLevel] heat level: 0 for an
/// empty day, then 1 session → 1, 2 → 2, 3 → 3, 4+ → 4. Deliberately coarse —
/// the heatmap is a glance, not a precise readout.
int heatLevel(int count) {
  if (count <= 0) return 0;
  return count < maxHeatLevel ? count : maxHeatLevel;
}
