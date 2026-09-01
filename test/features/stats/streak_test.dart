import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/streak.dart';

void main() {
  // A fixed "now" so the tests don't drift across midnight.
  final now = DateTime(2026, 8, 29, 10, 30);
  DateTime daysAgo(int n, {int hour = 9}) =>
      DateTime(2026, 8, 29 - n, hour);

  test('no sessions is a zero streak', () {
    expect(currentStreak(const [], now: now), 0);
  });

  test('a session today alone is a one-day streak', () {
    expect(currentStreak([daysAgo(0)], now: now), 1);
  });

  test('today, yesterday, and the day before is three', () {
    expect(
      currentStreak([daysAgo(0), daysAgo(1), daysAgo(2)], now: now),
      3,
    );
  });

  test('multiple sessions on the same day count once', () {
    expect(
      currentStreak([
        daysAgo(0, hour: 8),
        daysAgo(0, hour: 20),
        daysAgo(1),
      ], now: now),
      2,
    );
  });

  test('a long unbroken run counts every day', () {
    expect(
      currentStreak([for (var d = 0; d < 10; d++) daysAgo(d)], now: now),
      10,
    );
  });

  test('a gap breaks the streak at the gap', () {
    expect(
      currentStreak([daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(4)], now: now),
      2,
    );
  });

  test('studied yesterday but not yet today still counts', () {
    expect(currentStreak([daysAgo(1), daysAgo(2)], now: now), 2);
  });

  test('last study was two days ago — streak has lapsed', () {
    expect(currentStreak([daysAgo(2), daysAgo(3)], now: now), 0);
  });

  test('order of the input does not matter', () {
    expect(
      currentStreak([daysAgo(2), daysAgo(0), daysAgo(1)], now: now),
      3,
    );
  });

  test('a run that crosses a month boundary still counts', () {
    final julyNow = DateTime(2026, 8, 2, 10);
    expect(
      currentStreak([
        DateTime(2026, 8, 2, 9),
        DateTime(2026, 8, 1, 9),
        DateTime(2026, 7, 31, 9),
        DateTime(2026, 7, 30, 9),
      ], now: julyNow),
      4,
    );
  });
}
