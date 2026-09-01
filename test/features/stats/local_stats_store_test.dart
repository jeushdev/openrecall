import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/stats/data/local_stats_store.dart';

void main() {
  // The project has no sqflite_common_ffi dev dependency and no real-DB store
  // tests; the meaningful contract to pin here is the no-database degradation,
  // which every other local store shares. The online path is covered by
  // supabase_stats_repository via the provider tests.
  group('LocalStatsStore with no database', () {
    final store = LocalStatsStore(null);

    test('is a no-op', () {
      expect(store.isNoop, isTrue);
    });

    test('recentCompletedSessions returns empty', () async {
      expect(await store.recentCompletedSessions(20), isEmpty);
    });

    test('runThroughsByDeck returns empty', () async {
      expect(await store.runThroughsByDeck(), isEmpty);
    });
  });
}
