import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'local_course_store.dart';
import 'supabase_course_repository.dart';

/// Wraps [SupabaseCourseRepository] with the local SQLite mirror (engine-v2-spec
/// §5). Reads are read-through: hit Supabase, refresh the `offline_courses`
/// mirror, return the remote data; if the Supabase call throws, fall back to
/// the mirror and otherwise rethrow.
///
/// There are no writes — course create / update / delete are not part of
/// Engine V2.
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
}
