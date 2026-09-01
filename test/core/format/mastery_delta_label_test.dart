import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/format/mastery_delta_label.dart';

void main() {
  test('a positive delta is prefixed with a plus sign', () {
    expect(masteryDeltaLabel(12), '+12%');
  });

  test('a zero delta has no sign', () {
    expect(masteryDeltaLabel(0), '0%');
  });

  test('a negative delta keeps its minus sign', () {
    expect(masteryDeltaLabel(-3), '-3%');
  });
}
