import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/application/decks_tab_view.dart';
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

/// The signed-in user's courses. The pickers and per-course theming that
/// consume it arrive with the UI revamp; the write path (U10) invalidates it.
final coursesProvider = FutureProvider<List<Course>>((ref) {
  return ref.watch(courseRepositoryProvider).fetchCourses();
});

/// Drives the create / update / delete course actions (ui-spec-v2 §3.2):
/// `isLoading` disables the submit button, `AsyncError` feeds a SnackBar. Holds
/// no value of its own — it only tracks the in-flight action, mirroring
/// [DecksController].
final courseControllerProvider =
    AsyncNotifierProvider<CourseController, void>(CourseController.new);

class CourseController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  CourseRepository get _repo => ref.read(courseRepositoryProvider);

  /// Runs [action], reflecting its progress in [state]. Returns the value on
  /// success, or `null` if it threw (the error is left in [state] for the UI).
  Future<T?> _run<T>(Future<T> Function() action) async {
    state = const AsyncLoading<void>();
    final result = await AsyncValue.guard(action);
    switch (result) {
      case AsyncError(:final error, :final stackTrace):
        state = AsyncError<void>(error, stackTrace);
        return null;
      case AsyncData(:final value):
        state = const AsyncData<void>(null);
        return value;
      case _:
        state = const AsyncData<void>(null);
        return null;
    }
  }

  Future<Course?> create({
    required String name,
    required String accentColor,
  }) async {
    final course = await _run(
      () => _repo.createCourse(name: name, accentColor: accentColor),
    );
    if (course != null) _refresh();
    return course;
  }

  // Named `updateCourse`, not `update`, because `AsyncNotifier` already defines
  // an `update` method (riverpod 3.x).
  Future<Course?> updateCourse({
    required String id,
    String? name,
    String? accentColor,
  }) async {
    final course = await _run(
      () => _repo.updateCourse(id: id, name: name, accentColor: accentColor),
    );
    if (course != null) _refresh();
    return course;
  }

  /// Deletes course [id] — its decks move to the default course first
  /// (repository contract). The default course is never deletable
  /// (ui-spec-v2 §3.1); handed its id, this records an error and no-ops.
  Future<void> delete(String id) async {
    await _run(() async {
      final courses = await ref.read(coursesProvider.future);
      if (courses.where((c) => c.id == id).any((c) => c.isDefault)) {
        throw StateError('The default course cannot be deleted.');
      }
      await _repo.deleteCourse(id);
    });
    // deleteCourse returns void, so success is "no error was recorded".
    if (!state.hasError) _refresh();
  }

  /// A course write moves the course list, the deck list (accents / grouping),
  /// and the Decks-tab view that joins the two.
  void _refresh() {
    ref.invalidate(coursesProvider);
    ref.invalidate(decksProvider);
    ref.invalidate(decksTabViewProvider);
  }
}
