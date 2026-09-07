import 'dart:async';

import 'package:open_recall/features/stats/domain/active_session.dart';
import 'package:open_recall/features/stats/domain/activity_feed.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/stats/domain/stats_repository.dart';

/// In-memory [StatsRepository] for provider tests, in the style of
/// [FakeDeckRepository]: a fixed dataset, a [calls] log, and an armed throw.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    List<CompletedSessionActivity>? recentCompletedSessions,
    Map<String, int>? runThroughs,
    List<CompletedSession>? completedSessions,
    List<ActiveSessionProgress>? activeSessions,
    Map<String, int>? sessionCountsByDeck,
  }) : _recentCompletedSessions = [...?recentCompletedSessions],
       _runThroughs = {...?runThroughs},
       _completedSessions = [...?completedSessions],
       _activeSessions = [...?activeSessions],
       _sessionCountsByDeck = {...?sessionCountsByDeck};

  final List<CompletedSessionActivity> _recentCompletedSessions;
  final Map<String, int> _runThroughs;
  final List<CompletedSession> _completedSessions;
  final List<ActiveSessionProgress> _activeSessions;
  final Map<String, int> _sessionCountsByDeck;

  final List<String> calls = <String>[];

  /// When set, the next call throws this and then clears it.
  Object? throwOnNextCall;

  /// When true, every fetch returns a future that never completes — an
  /// unreachable host, the case [statsLoadTimeoutProvider] bounds.
  bool hangForever = false;
  bool failRecent = false;
  bool failCompleted = false;

  void _maybeThrow() {
    final error = throwOnNextCall;
    if (error != null) {
      throwOnNextCall = null;
      throw error;
    }
  }

  Future<T> _hang<T>() => Completer<T>().future;

  @override
  Future<List<CompletedSessionActivity>> fetchRecentCompletedSessions({
    int limit = activityFeedLimit,
  }) async {
    calls.add('fetchRecentCompletedSessions(limit=$limit)');
    if (failRecent) throw StateError('recent sessions unavailable');
    _maybeThrow();
    if (hangForever) return _hang();
    return List.unmodifiable(_recentCompletedSessions.take(limit));
  }

  @override
  Future<Map<String, int>> fetchDeckRunThroughs() async {
    calls.add('fetchDeckRunThroughs()');
    _maybeThrow();
    if (hangForever) return _hang();
    return Map.unmodifiable(_runThroughs);
  }

  @override
  Future<List<ActiveSessionProgress>> fetchActiveSessions() async {
    calls.add('fetchActiveSessions()');
    _maybeThrow();
    if (hangForever) return _hang();
    return List.unmodifiable(_activeSessions);
  }

  @override
  Future<Map<String, int>> fetchSessionCountsByDeck() async {
    calls.add('fetchSessionCountsByDeck()');
    _maybeThrow();
    if (hangForever) return _hang();
    return Map.unmodifiable(_sessionCountsByDeck);
  }

  @override
  Future<List<CompletedSession>> fetchCompletedSessions({
    int limit = completedSessionsLimit,
  }) async {
    calls.add('fetchCompletedSessions(limit=$limit)');
    if (failCompleted) throw StateError('completed sessions unavailable');
    _maybeThrow();
    if (hangForever) return _hang();
    return List.unmodifiable(_completedSessions.take(limit));
  }
}
