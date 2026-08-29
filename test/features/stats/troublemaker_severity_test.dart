import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/domain/troublemaker_severity.dart';

void main() {
  test('bands fail_count into none / moderate / high at 3 and 5', () {
    expect(severityFor(0), TroublemakerSeverity.none);
    expect(severityFor(2), TroublemakerSeverity.none);
    expect(severityFor(3), TroublemakerSeverity.moderate);
    expect(severityFor(4), TroublemakerSeverity.moderate);
    expect(severityFor(5), TroublemakerSeverity.high);
    expect(severityFor(42), TroublemakerSeverity.high);
  });
}
