import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/study/domain/session_length.dart';

void main() {
  group('SessionLengthMode.db', () {
    test('untilMastered stores as uncapped', () {
      expect(SessionLengthMode.untilMastered.db, 'uncapped');
    });

    test('capped stores as capped', () {
      expect(SessionLengthMode.capped.db, 'capped');
    });
  });

  group('sessionLengthModeFromDb', () {
    test('reads both stored strings back', () {
      expect(sessionLengthModeFromDb('uncapped'), SessionLengthMode.untilMastered);
      expect(sessionLengthModeFromDb('capped'), SessionLengthMode.capped);
    });
  });

  test('the cap presets are 10/20/30/All', () {
    expect(sessionCapPresets, [10, 20, 30, null]);
  });
}
