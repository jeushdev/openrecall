import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/cache_first_course_repository.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';

import '../../support/fake_course_repository.dart';

/// A [LocalCourseStore] that reports a live database and returns a fixed cache.
class _FakeLocalCourseStore extends LocalCourseStore {
  _FakeLocalCourseStore(this._cached) : super(null);

  final List<Course> _cached;

  @override
  bool get isNoop => false;

  @override
  Future<void> refreshCourses(List<Course> remote) async {}

  @override
  Future<List<Course>> cachedCourses() async => _cached;
}

void main() {
  group('CacheFirstCourseRepository.fetchCourses offline', () {
    test('falls back to a non-empty mirror', () async {
      final remote = FakeCourseRepository()..throwOnNextCall = StateError('offline');
      final repo = CacheFirstCourseRepository(
        remote,
        _FakeLocalCourseStore([
          fakeCourse(id: 'default', isDefault: true),
          fakeCourse(id: 'bio'),
        ]),
        () => 'u1',
      );

      final courses = await repo.fetchCourses();

      expect(courses.map((c) => c.id), ['default', 'bio']);
    });

    test('returns an empty list rather than rethrowing when the mirror is empty',
        () async {
      final remote = FakeCourseRepository()..throwOnNextCall = StateError('offline');
      final repo = CacheFirstCourseRepository(
        remote,
        _FakeLocalCourseStore(const []),
        () => 'u1',
      );

      // The pre-fix behaviour rethrew here, which is what disabled the Deck
      // Creator's "Create" button offline (milestone UX1).
      expect(await repo.fetchCourses(), isEmpty);
    });

    test('rethrows when there is no local database at all', () async {
      final remote = FakeCourseRepository()..throwOnNextCall = StateError('offline');
      final repo = CacheFirstCourseRepository(
        remote,
        LocalCourseStore(null), // isNoop == true
        () => 'u1',
      );

      expect(repo.fetchCourses(), throwsStateError);
    });
  });
}
