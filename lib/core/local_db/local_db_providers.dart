import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/courses/data/local_course_store.dart';
import '../../features/decks/data/local_deck_store.dart';
import '../../features/stats/data/local_stats_store.dart';
import '../../features/study/data/local_study_store.dart';
import 'app_database.dart';
import 'application_cache.dart';

final applicationCacheProvider = Provider(
  (ref) => ApplicationCache(_db(ref), isCurrent: _scopeCheck(ref)),
);

/// The open [AppDatabase], or `null` when no local database is available —
/// which is the default. `main()` overrides this with the real instance after
/// [AppDatabase.open]; tests leave it `null` so the local stores below degrade
/// to no-ops and the cache-first repositories behave exactly like the plain
/// Supabase repositories.
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);

/// Web and native database-open failures remain online-only. Download UI will
/// consume this capability in milestone 4; absence is never a completed cache.
final localStorageAvailableProvider = Provider<bool>(
  (ref) => ref.watch(appDatabaseProvider) != null,
);

bool Function() _scopeCheck(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final generation = database?.scopeGeneration;
  return () =>
      (database?.scopeReady ?? true) && database?.scopeGeneration == generation;
}

Database? _db(Ref ref) => ref.watch(appDatabaseProvider)?.db;

/// The DAO for `offline_decks` / `offline_cards`.
final localDeckStoreProvider = Provider<LocalDeckStore>(
  (ref) => LocalDeckStore(_db(ref), isCurrent: _scopeCheck(ref)),
);

/// The DAO for `offline_study_sessions` / `offline_session_cards`.
final localStudyStoreProvider = Provider<LocalStudyStore>(
  (ref) => LocalStudyStore(_db(ref), isCurrent: _scopeCheck(ref)),
);

/// The DAO for `offline_courses`.
final localCourseStoreProvider = Provider<LocalCourseStore>(
  (ref) => LocalCourseStore(_db(ref), isCurrent: _scopeCheck(ref)),
);

/// The read-only DAO for the cross-deck stat aggregations (engine-v2-spec §6).
final localStatsStoreProvider = Provider<LocalStatsStore>(
  (ref) => LocalStatsStore(_db(ref), isCurrent: _scopeCheck(ref)),
);
