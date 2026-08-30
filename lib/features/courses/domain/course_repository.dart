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

  /// Permanently deletes course [id], first reassigning its decks to the user's
  /// default course (the FK is `NO ACTION`, so the reassignment must land
  /// first). The default course itself is never passed here — the controller
  /// guards against it.
  Future<void> deleteCourse(String id);
}
