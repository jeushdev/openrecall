import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/course.dart';
import '../domain/course_repository.dart';

/// The only class in the courses feature that talks to Supabase Postgres
/// directly. RLS (`courses_owner`) scopes every query to the signed-in user, so
/// no `user_id` filter is needed on reads.
class SupabaseCourseRepository implements CourseRepository {
  SupabaseCourseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Course>> fetchCourses() async {
    final rows = await _client
        .from('courses')
        .select('id, user_id, name, accent_color, is_default, '
            'created_at, updated_at')
        .order('created_at');
    return rows.map(Course.fromJson).toList();
  }
}
