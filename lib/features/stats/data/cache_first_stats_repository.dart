import '../domain/stats_repository.dart';
import '../domain/troublemaker_card.dart';
import 'local_stats_store.dart';
import 'supabase_stats_repository.dart';

/// Wraps [SupabaseStatsRepository] with the local mirror (engine-v2-spec §6):
/// hit Supabase, and on failure fall back to [LocalStatsStore]. There are no
/// writes.
///
/// The fallback follows `CacheFirstCourseRepository`'s rule — if the mirror is
/// absent (no local database) the original error is surfaced rather than a bare
/// empty result masking an offline failure. When a database exists, an empty
/// mirror is a legitimate answer (nothing downloaded / no sessions yet).
class CacheFirstStatsRepository implements StatsRepository {
  CacheFirstStatsRepository(this._remote, this._local);

  final SupabaseStatsRepository _remote;
  final LocalStatsStore _local;

  @override
  Future<List<TroublemakerCard>> fetchTroublemakers({
    int limit = appWideTroublemakerLimit,
  }) async {
    try {
      return await _remote.fetchTroublemakers(limit: limit);
    } catch (_) {
      if (_local.isNoop) rethrow;
      return _local.troublemakers(limit);
    }
  }

  @override
  Future<Map<String, int>> fetchDeckRunThroughs() async {
    try {
      return await _remote.fetchDeckRunThroughs();
    } catch (_) {
      if (_local.isNoop) rethrow;
      return _local.runThroughsByDeck();
    }
  }
}
