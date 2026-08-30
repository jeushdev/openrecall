import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'local_course_store.dart';
import 'supabase_course_repository.dart';

/// Wraps [SupabaseCourseRepository] with the local SQLite mirror (engine-v2-spec
/// §5). Reads are read-through: hit Supabase, refresh the `offline_courses`
/// mirror, return the remote data; if the Supabase call throws, fall back to
/// the mirror and otherwise rethrow.
///
/// Course create / update / delete are online-only (ui-spec-v2 §2): they pass
/// straight to [_remote] and simply fail when offline, exactly like
/// `CacheFirstDeckRepository`'s authoring methods. `offline_courses` carries no
/// `is_synced` column, so nothing here is ever pushed — the next read-through
/// [fetchCourses] re-pulls the mirror.
class CacheFirstCourseRepository implements CourseRepository {
  CacheFirstCourseRepository(this._remote, this._local);

  final SupabaseCourseRepository _remote;
  final LocalCourseStore _local;

  @override
  Future<List<Course>> fetchCourses() async {
    try {
      final remote = await _remote.fetchCourses();
      await _local.refreshCourses(remote);
      return remote;
    } catch (_) {
      final cached = await _local.cachedCourses();
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  // ---- online-only pass-throughs (ui-spec-v2 §2: authoring needs a connection) --

  @override
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  }) =>
      _remote.createCourse(name: name, accentColor: accentColor);

  @override
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) =>
      _remote.updateCourse(id: id, name: name, accentColor: accentColor);

  @override
  Future<void> deleteCourse(String id) => _remote.deleteCourse(id);
}
