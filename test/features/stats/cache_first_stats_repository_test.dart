import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/application_cache.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/data/cache_first_stats_repository.dart';
import 'package:open_recall/features/stats/data/local_stats_store.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';

import '../../support/fake_stats_repository.dart';
import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'successful completed-session pages are persisted with coverage',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final local = LocalStatsStore(database.db);
      final remote = FakeStatsRepository(
        completedSessions: [
          CompletedSession(
            sessionId: 's1',
            deckId: 'd1',
            studyMode: StudyMode.flip,
            startedAt: DateTime.utc(2026, 9, 7),
            completedAt: DateTime.utc(2026, 9, 7, 0, 10),
            cardsReviewed: 4,
          ),
        ],
      );
      final repository = CacheFirstStatsRepository(remote, local);

      await repository.fetchCompletedSessions();

      expect((await local.completedSessions(1000)).single.sessionId, 's1');
      expect(
        (await local.cacheState(completedSessionsCacheKey)).coverage,
        CacheCoverage.complete,
      );
    },
  );

  test('no-SQLite operation remains online-only', () async {
    final remote = FakeStatsRepository(
      completedSessions: [
        CompletedSession(
          startedAt: DateTime.utc(2026, 9, 7),
          completedAt: DateTime.utc(2026, 9, 7, 0, 10),
          cardsReviewed: 4,
        ),
      ],
    );
    final repository = CacheFirstStatsRepository(remote, LocalStatsStore(null));

    expect(await repository.fetchCompletedSessions(), hasLength(1));
    remote.failCompleted = true;
    await expectLater(repository.fetchCompletedSessions(), throwsStateError);
  });

  test('a page that fills its cap is exposed as partial coverage', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final local = LocalStatsStore(database.db);
    final repository = CacheFirstStatsRepository(
      FakeStatsRepository(
        completedSessions: [
          CompletedSession(
            sessionId: 's1',
            deckId: 'd1',
            studyMode: StudyMode.flip,
            startedAt: DateTime.utc(2026, 9, 7),
            completedAt: DateTime.utc(2026, 9, 7, 0, 10),
            cardsReviewed: 4,
          ),
        ],
      ),
      local,
    );

    await repository.fetchCompletedSessions(limit: 1);

    expect(
      (await local.cacheState(completedSessionsCacheKey)).coverage,
      CacheCoverage.partial,
    );
  });
}
