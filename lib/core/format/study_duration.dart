/// A short, human label for a span of study time on the Profile tab's metrics
/// (offline-and-ux milestone D) — "0m", "45m", "3h 20m", "12h".
///
/// Minutes are truncated (a part-minute does not round up), hours and minutes
/// are shown together, and a whole number of hours drops the "0m". Hand-rolled
/// to match the other `core/format/` helpers — the app pulls in no `intl`.
String formatStudyDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
