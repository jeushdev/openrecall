import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';

void main() {
  // The project has no sqflite_common_ffi dev dependency and no real-DB store
  // tests (see local_stats_store_test.dart). The contract pinned here is the
  // no-database degradation every local store shares, so a cache-first
  // repository wrapping this store behaves exactly like the plain Supabase one.
  // The real offline-authoring behaviour is covered by the manual airplane-mode
  // walkthrough in the spec-v4 verification checklist.
  group('LocalCourseStore with no database', () {
    final store = LocalCourseStore(null);

    test('is a no-op', () {
      expect(store.isNoop, isTrue);
    });

    test('refreshCourses does not throw', () async {
      await store.refreshCourses(const []);
    });

    test('cachedCourses returns empty', () async {
      expect(await store.cachedCourses(), isEmpty);
    });

    test('defaultCourseId returns null', () async {
      expect(await store.defaultCourseId(), isNull);
    });

    test('createCourse returns the course without persisting', () async {
      final course = await store.createCourse(
        id: 'c1',
        userId: 'u1',
        name: 'Biology',
        accentColor: 'green',
      );
      expect(course.id, 'c1');
      expect(course.name, 'Biology');
      expect(course.isDefault, isFalse);
    });

    test('updateCourse returns null (nothing to update)', () async {
      expect(await store.updateCourse(id: 'c1', name: 'x'), isNull);
    });

    test('deleteCourse does not throw', () async {
      await store.deleteCourse('c1', defaultCourseId: 'c0');
    });

    test('unsyncedCourses / courseDeletions return empty', () async {
      expect(await store.unsyncedCourses(), isEmpty);
      expect(await store.courseDeletions(), isEmpty);
    });

    test('markCourseSynced / clearCourseDeletion do not throw', () async {
      await store.markCourseSynced('c1', DateTime.utc(2026));
      await store.clearCourseDeletion('c1');
    });
  });
}
