import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/format/study_duration.dart';

void main() {
  test('zero renders as 0m', () {
    expect(formatStudyDuration(Duration.zero), '0m');
  });

  test('under an hour renders whole minutes', () {
    expect(formatStudyDuration(const Duration(minutes: 45)), '45m');
  });

  test('sub-minute rounds down to 0m', () {
    expect(formatStudyDuration(const Duration(seconds: 40)), '0m');
  });

  test('a whole number of hours drops the minutes', () {
    expect(formatStudyDuration(const Duration(hours: 12)), '12h');
  });

  test('hours and minutes render together', () {
    expect(
      formatStudyDuration(const Duration(hours: 3, minutes: 20)),
      '3h 20m',
    );
  });

  test('minutes are the remainder after whole hours', () {
    expect(
      formatStudyDuration(const Duration(hours: 1, minutes: 5, seconds: 30)),
      '1h 5m',
    );
  });
}
