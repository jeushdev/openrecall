import 'package:open_recall/features/courses/domain/course.dart';
import 'package:open_recall/features/courses/domain/course_repository.dart';

/// In-memory [CourseRepository] for provider tests. Holds a fixed course list
/// and records every call, in the style of [FakeDeckRepository].
class FakeCourseRepository implements CourseRepository {
  FakeCourseRepository({
    List<Course>? courses,
    Map<String, String>? deckCourseIds,
  })  : _courses = [...?courses],
        deckCourseIds = {...?deckCourseIds};

  final List<Course> _courses;

  /// `deckId -> courseId`, so [deleteCourse]'s decks-to-default reassignment
  /// (spec §3.1) is observable from a test without a real `decks` table.
  final Map<String, String> deckCourseIds;

  final List<String> calls = <String>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  int _idSeq = 0;

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

  @override
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  }) async {
    calls.add('createCourse(name=$name, accent=$accentColor)');
    _maybeThrow();
    final course = fakeCourse(
      id: 'course-${++_idSeq}',
      name: name,
      accentColor: accentColor,
    );
    _courses.add(course);
    return course;
  }

  @override
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) async {
    calls.add('updateCourse(id=$id, name=$name, accent=$accentColor)');
    _maybeThrow();
    final i = _courses.indexWhere((c) => c.id == id);
    final existing = _courses[i];
    final updated = Course(
      id: existing.id,
      userId: existing.userId,
      name: name ?? existing.name,
      accentColor: accentColor ?? existing.accentColor,
      isDefault: existing.isDefault,
      createdAt: existing.createdAt,
      updatedAt: existing.updatedAt,
    );
    _courses[i] = updated;
    return updated;
  }

  @override
  Future<void> reorderCourses(List<String> orderedIds) async {
    calls.add('reorderCourses([${orderedIds.join(', ')}])');
    _maybeThrow();
    // Reflect the new order in the in-memory list so a follow-up fetchCourses
    // sees it, and stamp each course's position to its new index.
    final byId = {for (final c in _courses) c.id: c};
    final reordered = <Course>[
      for (final (i, id) in orderedIds.indexed)
        if (byId[id] case final c?) _withPosition(c, i),
    ];
    // Keep any course not named in the order (shouldn't happen) at the end.
    for (final c in _courses) {
      if (!orderedIds.contains(c.id)) reordered.add(c);
    }
    _courses
      ..clear()
      ..addAll(reordered);
  }

  @override
  Future<void> deleteCourse(String id, {required String defaultCourseId}) async {
    calls.add('deleteCourse($id)');
    _maybeThrow();
    // Mirror the real two-step contract: reassign this course's decks to the
    // caller-supplied default course first, then drop the course row.
    deckCourseIds.updateAll(
      (deckId, courseId) => courseId == id ? defaultCourseId : courseId,
    );
    _courses.removeWhere((c) => c.id == id);
  }
}

Course _withPosition(Course c, int position) => Course(
      id: c.id,
      userId: c.userId,
      name: c.name,
      accentColor: c.accentColor,
      isDefault: c.isDefault,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      position: position,
    );

/// A plain [Course] for fixtures — only the fields the aggregation layer reads
/// matter, the rest get neutral values.
Course fakeCourse({
  required String id,
  String? name,
  String accentColor = 'slate',
  bool isDefault = false,
  int position = 0,
}) =>
    Course(
      id: id,
      userId: 'user-1',
      name: name ?? id,
      accentColor: accentColor,
      isDefault: isDefault,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      position: position,
    );
