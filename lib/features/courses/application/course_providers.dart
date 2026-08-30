import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../../core/ui/app_messenger.dart';
import '../../decks/application/deck_providers.dart';
import '../../decks/application/decks_tab_view.dart';
import '../../decks/application/pending_deletions.dart';
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
  ///
  /// Optimistic (milestone R1): the id lands in [pendingDeletionsProvider]
  /// straight away so the Decks-tab row disappears (and its decks re-home under
  /// the default course) before the two Supabase statements run. The caller
  /// does not await this; on success the real providers are invalidated and the
  /// pending id cleared once they've refetched, on failure the id is cleared
  /// (row returns) and a snackbar is shown.
  Future<void> delete(String id) async {
    // Read synchronously when the list is already loaded (the Decks tab is
    // showing it) so the optimistic `addCourse` below lands in the same tick as
    // the tap — no frame where the row is still there.
    final cached = ref.read(coursesProvider).asData?.value;
    final List<Course> courses =
        cached ?? await ref.read(coursesProvider.future);
    if (courses.where((c) => c.id == id).any((c) => c.isDefault)) {
      state = AsyncError<void>(
        StateError('The default course cannot be deleted.'),
        StackTrace.current,
      );
      return;
    }
    final defaultCourseId = courses.firstWhere((c) => c.isDefault).id;
    final pending = ref.read(pendingDeletionsProvider.notifier);
    pending.addCourse(id);

    final result = await AsyncValue.guard(
      () => _repo.deleteCourse(id, defaultCourseId: defaultCourseId),
    );
    if (result case AsyncError(:final error)) {
      pending.removeCourse(id);
      showAppSnackBar('Something went wrong: $error');
      return;
    }

    _refresh();
    ref.invalidate(tabDecksProvider);
    // Let the invalidated fetches land before releasing the pending id, so the
    // row doesn't flash back between the two.
    await _settle();
    pending.removeCourse(id);
  }

  Future<void> _settle() async {
    try {
      await ref.read(coursesProvider.future);
      await ref.read(tabDecksProvider.future);
    } catch (_) {
      // A refetch failure doesn't strand the delete — it already succeeded.
    }
  }

  /// A course write moves the course list, the deck list (accents / grouping),
  /// and the Decks-tab view that joins the two.
  void _refresh() {
    ref.invalidate(coursesProvider);
    ref.invalidate(decksProvider);
    ref.invalidate(decksTabViewProvider);
  }
}
