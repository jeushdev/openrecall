import 'course.dart';

/// The app's window onto the `courses` table.
///
/// Engine V2 (milestone 15) wires only the read path — listing the signed-in
/// user's courses. Create / update / delete are specced (engine-v2-spec §3.1)
/// but not exposed until the UI revamp, so they are deliberately absent here.
abstract interface class CourseRepository {
  /// Every course the signed-in user owns, oldest first (the default course,
  /// created at signup, sorts first).
  Future<List<Course>> fetchCourses();
}
