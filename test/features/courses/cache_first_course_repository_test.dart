import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/cache_first_course_repository.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/courses/domain/course.dart';

import '../../support/fake_course_repository.dart';

/// A [LocalCourseStore] that reports a live database and returns a fixed cache.
class _FakeLocalCourseStore extends LocalCourseStore {
  _FakeLocalCourseStore(this._cached) : super(null);

  final List<Course> _cached;
  final List<List<String>> reorderCourseCalls = [];

  @override
  bool get isNoop => false;

  @override
  Future<void> refreshCourses(List<Course> remote) async {}

  @override
  Future<List<Course>> cachedCourses() async => _cached;

  @override
  Future<void> reorderCourses(List<String> orderedIds) async {
    reorderCourseCalls.add(orderedIds);
  }
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

  group('CacheFirstCourseRepository.reorderCourses', () {
    test('delegates the new order straight to the remote', () async {
      final remote = FakeCourseRepository(courses: [
        fakeCourse(id: 'a', isDefault: true),
        fakeCourse(id: 'b'),
        fakeCourse(id: 'c'),
      ]);
      final repo = CacheFirstCourseRepository(
        remote,
        _FakeLocalCourseStore(const []),
        () => 'u1',
      );

      await repo.reorderCourses(['c', 'a', 'b']);

      expect(remote.calls, contains('reorderCourses([c, a, b])'));
    });

    test('offline, queues the new order into the local mirror instead of '
        'throwing', () async {
      final remote = FakeCourseRepository(courses: [fakeCourse(id: 'a')])
        ..throwOnNextCall = StateError('offline');
      final local = _FakeLocalCourseStore(const []);
      final repo = CacheFirstCourseRepository(remote, local, () => 'u1');

      await repo.reorderCourses(['b', 'a']); // must not throw

      expect(local.reorderCourseCalls.single, ['b', 'a']);
    });

    test('with no local database the offline error still propagates', () async {
      final remote = FakeCourseRepository(courses: [fakeCourse(id: 'a')])
        ..throwOnNextCall = StateError('offline');
      final repo = CacheFirstCourseRepository(
        remote,
        LocalCourseStore(null), // isNoop == true
        () => 'u1',
      );

      await expectLater(repo.reorderCourses(['a']), throwsStateError);
    });
  });
}
