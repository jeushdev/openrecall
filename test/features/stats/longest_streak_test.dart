import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/streak.dart';

void main() {
  DateTime day(int year, int month, int d, {int hour = 9}) =>
      DateTime(year, month, d, hour);

  test('no sessions is a zero longest streak', () {
    expect(longestStreak(const []), 0);
  });

  test('a single day is a longest streak of one', () {
    expect(longestStreak([day(2026, 8, 20)]), 1);
  });

  test('the longest unbroken run wins over a later shorter run', () {
    expect(
      longestStreak([
        // a five-day run
        day(2026, 8, 1),
        day(2026, 8, 2),
        day(2026, 8, 3),
        day(2026, 8, 4),
        day(2026, 8, 5),
        // gap, then a two-day run
        day(2026, 8, 10),
        day(2026, 8, 11),
      ]),
      5,
    );
  });

  test('a run entirely in the past still counts', () {
    expect(
      longestStreak([day(2020, 1, 1), day(2020, 1, 2), day(2020, 1, 3)]),
      3,
    );
  });

  test('multiple sessions on the same day collapse to one', () {
    expect(
      longestStreak([
        day(2026, 8, 1, hour: 7),
        day(2026, 8, 1, hour: 19),
        day(2026, 8, 2),
      ]),
      2,
    );
  });

  test('input order does not matter', () {
    expect(
      longestStreak([day(2026, 8, 3), day(2026, 8, 1), day(2026, 8, 2)]),
      3,
    );
  });

  test('a run that crosses a month boundary still counts', () {
    expect(
      longestStreak([
        day(2026, 7, 30),
        day(2026, 7, 31),
        day(2026, 8, 1),
        day(2026, 8, 2),
      ]),
      4,
    );
  });
}
