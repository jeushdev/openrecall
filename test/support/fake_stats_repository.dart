import 'package:open_recall/features/stats/domain/activity_feed.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/stats/domain/stats_repository.dart';

/// In-memory [StatsRepository] for provider tests, in the style of
/// [FakeDeckRepository]: a fixed dataset, a [calls] log, and an armed throw.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    List<CompletedSessionActivity>? recentCompletedSessions,
    Map<String, int>? runThroughs,
    List<DateTime>? completedSessionStarts,
  })  : _recentCompletedSessions = [...?recentCompletedSessions],
        _runThroughs = {...?runThroughs},
        _completedSessionStarts = [...?completedSessionStarts];

  final List<CompletedSessionActivity> _recentCompletedSessions;
  final Map<String, int> _runThroughs;
  final List<DateTime> _completedSessionStarts;

  final List<String> calls = <String>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  void _maybeThrow() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  @override
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  }) async {
    calls.add('fetchRecentCompletedSessions(limit=$limit)');
    _maybeThrow();
    return List.unmodifiable(_recentCompletedSessions.take(limit));
  }

  @override
  Future<Map<String, int>> fetchDeckRunThroughs() async {
    calls.add('fetchDeckRunThroughs()');
    _maybeThrow();
    return Map.unmodifiable(_runThroughs);
  }

  @override
  Future<List<DateTime>> fetchCompletedSessionStarts() async {
    calls.add('fetchCompletedSessionStarts()');
    _maybeThrow();
    return List.unmodifiable(_completedSessionStarts);
  }
}
