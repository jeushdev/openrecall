import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/local_db/app_database.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/stats/data/local_stats_store.dart';
import 'package:open_recall/features/stats/domain/completed_session.dart';
import 'package:open_recall/features/stats/domain/streak.dart';
import 'package:open_recall/features/stats/domain/study_metrics.dart';

import '../../support/local_db_harness.dart';

/// A fresh install launched offline has a real SQLite file with every table
/// present and zero rows. Every reader on the launch path must return a sensible
/// empty value rather than throwing — the app renders empty/locked states, it
/// does not crash (design spec, milestone E testing, test 1).
void main() {
  setUpAll(initLocalDbTestFfi);

  late AppDatabase database;

  setUp(() async => database = await openTestDatabase());
  tearDown(() async => database.close());

  test('deck readers return empty on a fresh store', () async {
    final store = LocalDeckStore(database.db);
    expect(await store.cachedDeckSummaries(), isEmpty);
    expect(await store.downloadedDeckIds(), isEmpty);
    expect(await store.pinnedDeckIds(), isEmpty);
    expect(await store.completeCardDeckIds(), isEmpty);
    expect(await store.isCardSetComplete('nope'), isFalse);
    expect(await store.isDownloaded('nope'), isFalse);
    expect(await store.cards('nope'), isEmpty);
    expect(await store.cardById('nope'), isNull);
  });

  test('course readers return empty on a fresh store', () async {
    final store = LocalCourseStore(database.db);
    expect(await store.cachedCourses(), isEmpty);
    expect(await store.defaultCourseId(), isNull);
  });

  test('stats readers return empty on a fresh store', () async {
    final store = LocalStatsStore(database.db);
    expect(await store.recentCompletedSessions(20), isEmpty);
    expect(await store.runThroughsByDeck(), isEmpty);
    expect(await store.completedSessions(completedSessionsLimit), isEmpty);
  });

  test('streak and metrics folds are defined over an empty history', () {
    expect(currentStreak(const <DateTime>[], now: DateTime(2026, 9, 1)), 0);
    final metrics = buildStudyMetrics(sessions: const <CompletedSession>[]);
    expect(metrics.currentStreak, 0);
    expect(metrics.longestStreak, 0);
    expect(metrics.sessionsCompleted, 0);
    expect(metrics.totalCardsReviewed, 0);
    expect(metrics.totalStudyTime, Duration.zero);
  });
}
