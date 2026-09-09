/// The Profile tab's "current streak": the number of consecutive calendar days,
/// ending today (or yesterday), on which the user completed at least one study
/// session (ui-spec-v1 §6.4).
///
/// Like "times cleared" (engine-v2-spec §6), this is **derived on read** from
/// `study_sessions.started_at`, never a stored counter — a stored counter would
/// hit the same last-write-wins raciness Engine V2 designed `mastery_count`
/// around.
///
/// [completedSessionStarts] is the `started_at` of every `completed` session
/// (order irrelevant). [now] defaults to `DateTime.now()` and exists for tests.
///
/// The streak only counts as "current" if the most recent study day is today or
/// yesterday; a two-day gap resets it to 0. Multiple sessions on one day count
/// once.
int currentStreak(Iterable<DateTime> completedSessionStarts, {DateTime? now}) {
  final days = <DateTime>{
    for (final start in completedSessionStarts) _dateOnly(start.toLocal()),
  };
  if (days.isEmpty) return 0;

  final today = _dateOnly(now ?? DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));

  final DateTime start;
  if (days.contains(today)) {
    start = today;
  } else if (days.contains(yesterday)) {
    start = yesterday;
  } else {
    return 0;
  }

  var count = 0;
  var cursor = start;
  while (days.contains(cursor)) {
    count++;
    // Step to the previous calendar day. Going back 12h from local midnight
    // lands squarely in the previous day in any timezone, DST transitions
    // included; [_dateOnly] then snaps back to that day's key.
    cursor = _dateOnly(cursor.subtract(const Duration(hours: 12)));
  }
  return count;
}

/// The Profile tab's "longest streak" (offline-and-ux milestone D): the longest
/// run of consecutive local-calendar days on which the user completed at least
/// one study session, anywhere in their history.
///
/// Like [currentStreak], this is derived on read from `study_sessions.started_at`
/// and works in the device-local timezone. [completedSessionStarts] is the
/// `started_at` of every `completed` session (order irrelevant). Multiple
/// sessions on one day count once.
int longestStreak(Iterable<DateTime> completedSessionStarts) {
  final days = <DateTime>{
    for (final start in completedSessionStarts) _dateOnly(start.toLocal()),
  };
  if (days.isEmpty) return 0;

  var longest = 0;
  for (final day in days) {
    // Count a run only from its first day — the day before is not a study day.
    final previous = _dateOnly(day.subtract(const Duration(hours: 12)));
    if (days.contains(previous)) continue;

    var length = 0;
    var cursor = day;
    while (days.contains(cursor)) {
      length++;
      cursor = _dateOnly(cursor.add(const Duration(hours: 36)));
    }
    if (length > longest) longest = length;
  }
  return longest;
}

/// Strips the time component, keeping the calendar date in local time.
DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
