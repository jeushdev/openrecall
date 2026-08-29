import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/courses/data/local_course_store.dart';
import '../../features/decks/data/local_deck_store.dart';
import '../../features/stats/data/local_stats_store.dart';
import '../../features/study/data/local_study_store.dart';
import 'app_database.dart';

/// The open [AppDatabase], or `null` when no local database is available —
/// which is the default. `main()` overrides this with the real instance after
/// [AppDatabase.open]; tests leave it `null` so the local stores below degrade
/// to no-ops and the cache-first repositories behave exactly like the plain
/// Supabase repositories.
final appDatabaseProvider = Provider<AppDatabase?>((ref) => null);

Database? _db(Ref ref) => ref.watch(appDatabaseProvider)?.db;

/// The DAO for `offline_decks` / `offline_cards`.
final localDeckStoreProvider =
    Provider<LocalDeckStore>((ref) => LocalDeckStore(_db(ref)));

/// The DAO for `offline_study_sessions` / `offline_session_cards`.
final localStudyStoreProvider =
    Provider<LocalStudyStore>((ref) => LocalStudyStore(_db(ref)));

/// The DAO for `offline_courses`.
final localCourseStoreProvider =
    Provider<LocalCourseStore>((ref) => LocalCourseStore(_db(ref)));

/// The read-only DAO for the cross-deck stat aggregations (engine-v2-spec §6).
final localStatsStoreProvider =
    Provider<LocalStatsStore>((ref) => LocalStatsStore(_db(ref)));
