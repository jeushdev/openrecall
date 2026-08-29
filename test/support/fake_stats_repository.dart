import 'package:open_recall/features/stats/domain/stats_repository.dart';
import 'package:open_recall/features/stats/domain/troublemaker_card.dart';

/// In-memory [StatsRepository] for provider tests, in the style of
/// [FakeDeckRepository]: a fixed dataset, a [calls] log, and an armed throw.
class FakeStatsRepository implements StatsRepository {
  FakeStatsRepository({
    List<TroublemakerCard>? troublemakers,
    Map<String, int>? runThroughs,
  })  : _troublemakers = [...?troublemakers],
        _runThroughs = {...?runThroughs};

  final List<TroublemakerCard> _troublemakers;
  final Map<String, int> _runThroughs;

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
  Future<List<TroublemakerCard>> fetchTroublemakers({
    int limit = appWideTroublemakerLimit,
  }) async {
    calls.add('fetchTroublemakers(limit=$limit)');
    _maybeThrow();
    return List.unmodifiable(_troublemakers.take(limit));
  }

  @override
  Future<Map<String, int>> fetchDeckRunThroughs() async {
    calls.add('fetchDeckRunThroughs()');
    _maybeThrow();
    return Map.unmodifiable(_runThroughs);
  }
}
