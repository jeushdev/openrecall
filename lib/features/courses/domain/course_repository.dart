import 'course.dart';

/// The app's window onto the `courses` table.
///
/// Engine V2 (milestone 15) wired only the read path. The course write path
/// (ui-spec-v2 §3.1, milestone U10) adds create / update / delete. All three
/// are online-only — [CacheFirstCourseRepository] passes them straight to
/// Supabase and lets the call fail when offline.
abstract interface class CourseRepository {
  /// Every course the signed-in user owns, oldest first (the default course,
  /// created at signup, sorts first).
  Future<List<Course>> fetchCourses();

  /// Inserts a course for the signed-in user and returns it. [accentColor] must
  /// be one of the eight named accent keys (caller-validated; the DB check
  /// constraint is the backstop). The new course is never the default.
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  });

  /// Updates only the non-null fields of course [id] and returns the new row.
  /// `updated_at` is left to the database trigger.
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  });

  /// Permanently deletes course [id], first reassigning its decks to
  /// [defaultCourseId] (the FK is `NO ACTION`, so the reassignment must land
  /// first). The caller passes the default course's id — [CourseController]
  /// already has the course list in hand — so this is two round-trips, not a
  /// self-lookup plus two. The default course itself is never passed as [id];
  /// the controller guards against it.
  Future<void> deleteCourse(String id, {required String defaultCourseId});

  /// Persists a manual reordering of the user's whole course list: each id in
  /// [orderedIds] gets its list index as its `position` (milestone B). One
  /// batched round-trip; `updated_at` is left to the database trigger.
  /// Online-only — throws when offline, and the caller reverts its optimistic
  /// state on that failure ([CacheFirstCourseRepository] adds no local queue for
  /// reorder; that arrives with the milestone E write queue).
  Future<void> reorderCourses(List<String> orderedIds);
}
