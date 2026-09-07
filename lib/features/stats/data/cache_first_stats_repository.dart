import '../domain/active_session.dart';
import '../domain/activity_feed.dart';
import '../domain/completed_session.dart';
import '../domain/completed_session_activity.dart';
import '../domain/stats_repository.dart';
import '../../../core/local_db/application_cache.dart';
import 'local_stats_store.dart';

/// Persists successful remote session projections into the existing SQLite
/// session mirror. Providers own the local-first read and background refresh so
/// a refresh error can never replace visible cached data.
class CacheFirstStatsRepository implements StatsRepository {
  CacheFirstStatsRepository(this._remote, this._local);

  final StatsRepository _remote;
  final LocalStatsStore _local;

  @override
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  }) async {
    final sessions = await _remote.fetchRecentCompletedSessions(limit: limit);
    await _local.saveRecentCompletedSessions(
      sessions,
      coverage: sessions.length < limit
          ? CacheCoverage.complete
          : CacheCoverage.partial,
    );
    return _local.isNoop ? sessions : _local.recentCompletedSessions(limit);
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

  @override
  Future<List<ActiveSessionProgress>> fetchActiveSessions() async {
    final sessions = await _remote.fetchActiveSessions();
    await _local.saveActiveSessions(sessions);
    return _local.isNoop ? sessions : _local.activeSessions();
  }

  @override
  Future<Map<String, int>> fetchSessionCountsByDeck() async {
    final sessions = await _remote.fetchCompletedSessions();
    await _local.saveCompletedSessions(
      sessions,
      coverage: sessions.length < completedSessionsLimit
          ? CacheCoverage.complete
          : CacheCoverage.partial,
    );
    if (!_local.isNoop) return _local.sessionCountsByDeck();
    if (sessions.isEmpty || sessions.any((session) => session.deckId == null)) {
      // Compatibility for lean repository projections used by older clients
      // and tests. The live Supabase projection always carries deck_id.
      return _remote.fetchSessionCountsByDeck();
    }
    final counts = <String, int>{};
    for (final session in sessions) {
      final deckId = session.deckId!;
      counts[deckId] = (counts[deckId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<CompletedSession>> fetchCompletedSessions({
    int limit = completedSessionsLimit,
  }) async {
    final sessions = await _remote.fetchCompletedSessions(limit: limit);
    await _local.saveCompletedSessions(
      sessions,
      coverage: sessions.length < limit
          ? CacheCoverage.complete
          : CacheCoverage.partial,
    );
    return _local.isNoop ? sessions : _local.completedSessions(limit);
  }
}
