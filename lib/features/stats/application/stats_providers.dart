import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../../courses/application/course_providers.dart';
import '../../decks/application/deck_providers.dart';
import '../data/cache_first_stats_repository.dart';
import '../data/supabase_stats_repository.dart';
import '../domain/course_summary.dart';
import '../domain/overall_mastery.dart';
import '../domain/stats_repository.dart';
import '../domain/troublemaker_card.dart';

/// The APIs behind the future Mastery / Stats screen (engine-v2-spec §6).
/// Providers + repository methods only — no widgets in Engine V2.

/// The live repository is the Supabase-backed one wrapped in the cache-first
/// layer: reads fall back to the local SQLite mirror. Tests override this with a
/// fake.
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return CacheFirstStatsRepository(
    SupabaseStatsRepository(Supabase.instance.client),
    ref.watch(localStatsStoreProvider),
  );
});

/// The single app-wide, card-weighted mastery % (0–100). Pure derivation of
/// [decksProvider] — which already falls back to the local mirror (or an empty
/// list) when there is no connectivity and no database, so this degrades
/// cleanly with `appDatabaseProvider` null.
final overallMasteryProvider = FutureProvider<int>((ref) async {
  final decks = await ref.watch(decksProvider.future);
  return overallMasteryPercent(decks);
});

/// The user's most-failed cards across every deck, most-failed first.
final troublemakersProvider = FutureProvider<List<TroublemakerCard>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchTroublemakers();
});

/// "Times fully cleared" per deck (engine-v2-spec §4.3), keyed by deck id.
final deckRunThroughsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchDeckRunThroughs();
});

/// Per-course rollups. Pure derivation of [coursesProvider] + [decksProvider],
/// both of which already degrade cleanly when offline.
final courseSummariesProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final courses = await ref.watch(coursesProvider.future);
  final decks = await ref.watch(decksProvider.future);
  return rollUpCourses(courses, decks);
});
