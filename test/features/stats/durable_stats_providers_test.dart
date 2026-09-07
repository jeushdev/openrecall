import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/core/local_db/application_cache.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/courses/application/course_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/deck.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/home/application/home_providers.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/features/stats/data/local_stats_store.dart';
import 'package:open_recall/features/stats/domain/active_session.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/completed_session_activity.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/fake_course_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_stats_repository.dart';
import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);

  test(
    'persisted history renders while remote futures remain unresolved',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'open-recall-m3-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}history.db';
      var database = await AppDatabase.open(path: path);
      final local = LocalStatsStore(database.db);
      final started = DateTime.utc(2026, 9, 7, 10);
      await local.saveRecentCompletedSessions([
        CompletedSessionActivity(
          sessionId: 'cached-session',
          deckId: 'd1',
          studyMode: StudyMode.flip,
          startedAt: started,
          completedAt: started.add(const Duration(minutes: 10)),
          masteryDelta: 4,
          cardsReviewed: 3,
        ),
      ], coverage: CacheCoverage.complete);
      await local.saveCompletedSessions([
        CompletedSession(
          sessionId: 'cached-session',
          deckId: 'd1',
          studyMode: StudyMode.flip,
          startedAt: started,
          completedAt: started.add(const Duration(minutes: 10)),
          cardsReviewed: 3,
        ),
      ], coverage: CacheCoverage.complete);
      await database.close();
      database = await AppDatabase.open(path: path);
      addTearDown(database.close);
      final remote = FakeStatsRepository()..hangForever = true;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          statsRepositoryProvider.overrideWithValue(remote),
          statsLoadTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          deckRepositoryProvider.overrideWithValue(
            FakeDeckRepository(
              decks: [
                DeckSummary(
                  id: 'd1',
                  name: 'Cached deck',
                  lastStudiedAt: null,
                  totalCards: 3,
                  dueCards: 0,
                  masteryPercent: 100,
                ),
              ],
            ),
          ),
          courseRepositoryProvider.overrideWithValue(FakeCourseRepository()),
        ],
      );
      addTearDown(container.dispose);

      final history = await container.read(historyLogProvider.future);
      final days = await container.read(dailyActivityProvider.future);
      expect(history.single.deckName, 'Cached deck');
      expect(days[DateTime(2026, 9, 7)], 1);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(container.read(recentCompletedSessionsProvider).hasValue, isTrue);
    },
  );

  test(
    'Dashboard retains cached active sessions after refresh failure',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      await LocalStatsStore(database.db).saveActiveSessions([
        ActiveSessionProgress(
          sessionId: 'active-1',
          deckId: 'd1',
          studyMode: StudyMode.flip,
          lengthMode: SessionLengthMode.untilMastered,
          cardScope: CardScope.all,
          cappedLength: null,
          startedAt: DateTime.utc(2026, 9, 7),
          masteredCards: 2,
          totalCards: 4,
        ),
      ]);
      final remote = FakeStatsRepository()..failRecent = true;
      remote.throwOnNextCall = StateError('offline');
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          statsRepositoryProvider.overrideWithValue(remote),
          statsLoadTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          deckRepositoryProvider.overrideWithValue(
            FakeDeckRepository(
              decks: [
                DeckSummary(
                  id: 'd1',
                  name: 'Cached deck',
                  lastStudiedAt: null,
                  totalCards: 4,
                  dueCards: 2,
                  masteryPercent: 50,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final dashboard = await container.read(activeSessionsProvider.future);
      expect(dashboard.single.percentComplete, 50);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(container.read(activeSessionProgressProvider).value, hasLength(1));
      expect(container.read(activeSessionProgressProvider).hasError, isFalse);
    },
  );
}
