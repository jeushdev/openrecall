import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../data/cache_first_course_repository.dart';
import '../data/supabase_course_repository.dart';
import '../domain/course.dart';
import '../domain/course_repository.dart';

/// The live repository is the Supabase-backed one wrapped in the cache-first
/// layer (engine-v2-spec §5): reads fall back to the local `offline_courses`
/// mirror. Tests override this with a fake.
final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CacheFirstCourseRepository(
    SupabaseCourseRepository(Supabase.instance.client),
    ref.watch(localCourseStoreProvider),
  );
});

/// The signed-in user's courses. Read-only in Engine V2 — the pickers and
/// per-course theming that consume it arrive with the UI revamp.
final coursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).fetchCourses();
});
