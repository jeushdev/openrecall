import '../../../core/ids.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';
import 'local_course_store.dart';

/// Wraps the Supabase-backed course repository with the local SQLite mirror
/// (engine-v2-spec §5, spec-v4 §4). Reads are read-through: hit Supabase, refresh
/// the
/// `offline_courses` mirror, return the remote data; if the Supabase call
/// throws, fall back to the mirror — including an empty one, since "no courses
/// cached yet" is a valid offline state, not an error (every consumer of
/// `coursesProvider` already degrades on an empty list).
///
/// Course create / update / delete are cache-first with a local-queue fallback:
/// they try [_remote] first and, when that throws (typically: offline), write
/// the [_local] store with a client-generated UUID and `is_synced = 0` so
/// [SyncService] pushes the row on reconnect. When there is no local database
/// (`_local.isNoop`) the remote error is rethrown, so the repository behaves
/// exactly like the plain Supabase one.
class CacheFirstCourseRepository implements CourseRepository {
  CacheFirstCourseRepository(this._remote, this._local, this._currentUserId);

  /// The Supabase-backed repository in production; a fake in tests. Typed as the
  /// interface so the cache-first logic can be unit-tested without a client.
  final CourseRepository _remote;
  final LocalCourseStore _local;
  final String? Function() _currentUserId;

  @override
  Future<List<Course>> fetchCourses() async {
    try {
      final remote = await _remote.fetchCourses();
      await _local.refreshCourses(remote);
      return remote;
    } catch (_) {
      // With no local mirror there is nothing to fall back to — behave like the
      // plain Supabase repo and surface the error.
      if (_local.isNoop) rethrow;
      return _local.cachedCourses();
    }
  }

  @override
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  }) async {
    try {
      return await _remote.createCourse(name: name, accentColor: accentColor);
    } catch (_) {
      if (_local.isNoop) rethrow;
      return _local.createCourse(
        id: newUuid(),
        userId: _currentUserId(),
        name: name,
        accentColor: accentColor,
      );
    }
  }

  @override
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) async {
    try {
      return await _remote.updateCourse(
        id: id,
        name: name,
        accentColor: accentColor,
      );
    } catch (_) {
      if (_local.isNoop) rethrow;
      final updated = await _local.updateCourse(
        id: id,
        name: name,
        accentColor: accentColor,
      );
      if (updated == null) rethrow;
      return updated;
    }
  }

  @override
  Future<void> deleteCourse(String id, {required String defaultCourseId}) async {
    try {
      await _remote.deleteCourse(id, defaultCourseId: defaultCourseId);
    } catch (_) {
      if (_local.isNoop) rethrow;
      await _local.deleteCourse(id, defaultCourseId: defaultCourseId);
    }
  }

  /// Straight passthrough to Supabase — reorder has no local-queue fallback yet
  /// (milestone B). A failure (offline) propagates so the caller reverts its
  /// optimistic order; milestone E routes this through the write queue instead.
  @override
  Future<void> reorderCourses(List<String> orderedIds) =>
      _remote.reorderCourses(orderedIds);
}
