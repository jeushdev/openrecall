/// A short, human relative-time label for the Mastery tab's activity feed
/// (milestone C) — "just now", "5m ago", "3h ago", "yesterday", "3d ago", then
/// an absolute `YYYY-MM-DD` once something is a week or more old.
///
/// Sub-day buckets are measured by elapsed duration; "yesterday" and "Nd ago"
/// are measured by calendar-day difference in the same (local) timezone as
/// [now]. Pass [now] in tests; it defaults to [DateTime.now].
String relativeTime(DateTime timestamp, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final elapsed = current.difference(timestamp);

  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final daysApart = today.difference(day).inDays;

  if (daysApart <= 0) return '${elapsed.inHours}h ago';
  if (daysApart == 1) return 'yesterday';
  if (daysApart < 7) return '${daysApart}d ago';

  return '${day.year}-${_two(day.month)}-${_two(day.day)}';
}

String _two(int n) => n.toString().padLeft(2, '0');
