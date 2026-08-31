import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/domain/course.dart';

void main() {
  Map<String, dynamic> row() => {
        'id': 'course-1',
        'user_id': 'user-1',
        'name': 'Biology',
        'accent_color': 'green',
        'is_default': false,
        'created_at': '2026-08-01T00:00:00Z',
        'updated_at': '2026-08-01T00:00:00Z',
      };

  group('Course.fromJson', () {
    test('reads the manual-order position, defaulting to 0 when absent', () {
      expect(Course.fromJson({...row(), 'position': 5}).position, 5);
      expect(Course.fromJson(row()).position, 0);
    });

    test('position participates in equality', () {
      final a = Course.fromJson({...row(), 'position': 1});
      final b = Course.fromJson({...row(), 'position': 2});
      expect(a, isNot(b));
      expect(a, Course.fromJson({...row(), 'position': 1}));
    });
  });
}
