import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/reorder.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';

/// The only class in the courses feature that talks to Supabase Postgres
/// directly. RLS (`courses_owner`) scopes every query to the signed-in user, so
/// no `user_id` filter is needed on reads.
class SupabaseCourseRepository implements CourseRepository {
  SupabaseCourseRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, user_id, name, accent_color, is_default, created_at, updated_at';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Course>> fetchCourses() async {
    final rows = await _client
        .from('courses')
        .select(_columns)
        .order('position')
        .order('created_at');
    return rows.map(Course.fromJson).toList();
  }

  @override
  Future<void> reorderCourses(List<String> orderedIds) async {
    // One batched round-trip via a SECURITY INVOKER function — RLS
    // (`courses_owner`) still scopes the UPDATE, so ids the user does not own
    // simply match no row. `updated_at` is left to the database trigger.
    await _client.rpc('set_course_positions', params: {
      'items': [
        for (final e in positionsForOrder(orderedIds).entries)
          {'id': e.key, 'position': e.value},
      ],
    });
  }

  @override
  Future<Course> createCourse({
    required String name,
    required String accentColor,
  }) async {
    // is_default defaults to false server-side. RLS (courses_owner) checks the
    // user_id we pass matches the signed-in user.
    final row = await _client
        .from('courses')
        .insert({
          'user_id': _userId,
          'name': name,
          'accent_color': accentColor,
        })
        .select(_columns)
        .single();
    return Course.fromJson(row);
  }

  @override
  Future<Course> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) async {
    // updated_at is left to the database trigger (CLAUDE.md).
    final row = await _client
        .from('courses')
        .update({
          'name': ?name,
          'accent_color': ?accentColor,
        })
        .eq('id', id)
        .select(_columns)
        .single();
    return Course.fromJson(row);
  }

  @override
  Future<void> deleteCourse(String id, {required String defaultCourseId}) async {
    // Two RLS-scoped statements, in order (ui-spec-v2 §3.1). The decks FK is
    // NO ACTION, so this course's decks must move to the default course before
    // the course row can be deleted. The default course id comes from the
    // caller (milestone R1) — no self-lookup here.
    await _client
        .from('decks')
        .update({'course_id': defaultCourseId}).eq('course_id', id);
    await _client.from('courses').delete().eq('id', id);
  }
}
