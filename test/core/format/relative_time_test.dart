import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/format/relative_time.dart';

void main() {
  final now = DateTime(2026, 9, 1, 12, 0);

  test('under a minute reads "just now"', () {
    expect(relativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        'just now');
  });

  test('minutes within the hour', () {
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago');
  });

  test('hours earlier the same calendar day', () {
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago');
  });

  test('the previous calendar day reads "yesterday"', () {
    expect(relativeTime(DateTime(2026, 8, 31, 9, 0), now: now), 'yesterday');
  });

  test('a few days back reads "Nd ago"', () {
    expect(relativeTime(DateTime(2026, 8, 29, 9, 0), now: now), '3d ago');
  });

  test('a week or more back reads an absolute date', () {
    expect(relativeTime(DateTime(2026, 8, 14, 9, 0), now: now), '2026-08-14');
  });

  test('a future timestamp from clock skew still reads "just now"', () {
    expect(relativeTime(now.add(const Duration(minutes: 2)), now: now),
        'just now');
  });
}
