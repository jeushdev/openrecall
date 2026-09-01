/// The "+X%" headline the Session Summary shows for a run's whole-deck mastery
/// change (spec §7), reused by the Mastery tab's activity feed (milestone C) so
/// a completed-session row is phrased identically.
///
/// Zero is rendered as `"0%"` (no sign); a negative delta keeps its `-`.
String masteryDeltaLabel(int delta) {
  final sign = delta > 0 ? '+' : '';
  return '$sign$delta%';
}
