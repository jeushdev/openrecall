import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/courses/domain/course_repository.dart';

/// In-memory [CourseRepository] for provider tests. Holds a fixed course list
/// and records every call, in the style of [FakeDeckRepository].
class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({List<Course>? courses}) : _courses = [...?courses];

  final List<Course> _courses;

  final List<String> calls = <String>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  void _maybeThrow() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  @override
  Future<List<Course>> fetchCourses() async {
    calls.add('fetchCourses()');
    _maybeThrow();
    return List.unmodifiable(_courses);
  }
}

/// A plain [Course] for fixtures — only the fields the aggregation layer reads
/// matter, the rest get neutral values.
Course fakeCourse({
  required String id,
  String? name,
  String accentColor = 'slate',
  bool isDefault = false,
}) =>
    Course(
      id: id,
      userId: 'user-1',
      name: name ?? id,
      accentColor: accentColor,
      isDefault: isDefault,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
