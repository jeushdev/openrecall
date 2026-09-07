import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/core/local_db/application_cache.dart';
import 'package:open_recall/features/decks/domain/study_mode.dart';
import 'package:open_recall/features/stats/data/local_stats_store.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:open_recall/features/study/domain/session_length.dart';
import 'package:open_recall/features/study/domain/session_status.dart';
import 'package:open_recall/features/study/domain/study_session.dart';

import '../../support/local_db_harness.dart';

void main() {
  setUpAll(initLocalDbTestFfi);
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

    test('completedSessions returns empty', () async {
      expect(await store.completedSessions(1000), isEmpty);
    });

    test('activeSessions returns empty', () async {
      expect(await store.activeSessions(), isEmpty);
    });

    test('sessionCountsByDeck returns empty', () async {
      expect(await store.sessionCountsByDeck(), isEmpty);
    });

    test('cache state is unavailable rather than complete', () async {
      final state = await store.cacheState(completedSessionsCacheKey);
      expect(state.available, isFalse);
      expect(state.hasCachedData, isFalse);
      expect(state.isComplete, isFalse);
    });
  });

  test(
    'remote rows merge by id without replacing a pending local completion',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final study = LocalStudyStore(database.db);
      final stats = LocalStatsStore(database.db);
      final started = DateTime.utc(2026, 9, 7, 10);
      await study.insertSession(
        StudySession(
          id: 'shared-id',
          deckId: 'local-deck',
          status: SessionStatus.completed,
          studyMode: StudyMode.flip,
          lengthMode: SessionLengthMode.untilMastered,
          cappedLength: null,
          masteryDelta: 2,
          startedAt: started,
          completedAt: started.add(const Duration(minutes: 10)),
        ),
        'u1',
        synced: false,
      );

      final remote = [
        CompletedSession(
          sessionId: 'shared-id',
          deckId: 'remote-deck',
          studyMode: StudyMode.cloze,
          lengthMode: SessionLengthMode.capped,
          cardScope: CardScope.all,
          cappedLength: 5,
          masteryDelta: 9,
          startedAt: started,
          completedAt: started.add(const Duration(minutes: 12)),
          cardsReviewed: 5,
        ),
        CompletedSession(
          sessionId: 'remote-only',
          deckId: 'remote-deck',
          studyMode: StudyMode.flip,
          startedAt: started.subtract(const Duration(days: 1)),
          completedAt: started.subtract(const Duration(hours: 23)),
          cardsReviewed: 3,
        ),
      ];
      await stats.saveCompletedSessions(
        remote,
        coverage: CacheCoverage.partial,
      );
      await stats.saveCompletedSessions(
        remote,
        coverage: CacheCoverage.partial,
      );

      final stored = await stats.completedSessions(1000);
      expect(stored.map((session) => session.sessionId).toSet(), {
        'shared-id',
        'remote-only',
      });
      expect(stored, hasLength(2));
      expect(
        stored
            .singleWhere((session) => session.sessionId == 'shared-id')
            .deckId,
        'local-deck',
      );
      final state = await stats.cacheState(completedSessionsCacheKey);
      expect(state.coverage, CacheCoverage.partial);
    },
  );

  test('completed-session cache survives a database restart', () async {
    final directory = await Directory.systemTemp.createTemp('open-recall-m3-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}stats.db';
    var database = await AppDatabase.open(path: path);
    final started = DateTime.utc(2026, 9, 6, 8);
    await LocalStatsStore(database.db).saveCompletedSessions([
      CompletedSession(
        sessionId: 'persisted',
        deckId: 'deck-1',
        studyMode: StudyMode.feynman,
        startedAt: started,
        completedAt: started.add(const Duration(minutes: 20)),
        cardsReviewed: 8,
      ),
    ], coverage: CacheCoverage.complete);
    await database.close();

    database = await AppDatabase.open(path: path);
    addTearDown(database.close);
    final restored = await LocalStatsStore(database.db).completedSessions(1000);
    expect(restored.single.sessionId, 'persisted');
    expect(
      (await LocalStatsStore(database.db).cacheState(completedSessionsCacheKey))
          .isComplete,
      isTrue,
    );
  });
}
