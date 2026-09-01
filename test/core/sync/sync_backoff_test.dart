import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/sync/sync_service.dart';
import 'package:open_recall/features/courses/data/local_course_store.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/study/data/local_study_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/local_db_harness.dart';

/// A [SyncService] whose Supabase-touching legs are stubbed out, so a test can
/// drive the outcome-tracking + reconnect-backoff logic (milestone E3 Task 5)
/// without a live client. `drain` decides whether the (single) queued deck is
/// marked synced — i.e. whether the pass "worked".
class _StubSyncService extends SyncService {
  _StubSyncService(
    this._decks,
    SupabaseClient client,
    LocalCourseStore courses,
    LocalStudyStore study,
    ConnectivityService connectivity,
  ) : super(client, _decks, courses, study, connectivity);

  final LocalDeckStore _decks;

  bool drain = false;
  int pushDecksCalls = 0;

  @override
  String? currentUserId() => 'u1';

  @override
  Future<void> pushCourses(String userId) async {}

  @override
  Future<void> pushDecks(String userId) async {
    pushDecksCalls++;
    if (!drain) return;
    for (final d in await _decks.unsyncedDecks()) {
      await _decks.markDeckSynced(d.id, DateTime.utc(2026, 2));
    }
  }

  @override
  Future<void> pushCardContent() async {}
  @override
  Future<void> pushCards() async {}
  @override
  Future<void> pushSessions() async {}
  @override
  Future<void> pushSessionCards() async {}
  @override
  Future<void> processDeletions() async {}
  @override
  Future<void> pushDeckPositions(List<DirtyDeck> dirty) async {}
  @override
  Future<void> pushCoursePositions(List<DirtyCourse> dirty) async {}
}

void main() {
  setUpAll(initLocalDbTestFfi);

  late LocalDeckStore decks;
  late _StubSyncService service;

  setUp(() async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    decks = LocalDeckStore(db.db);
    // One queued, never-synced deck so the pending count is non-zero.
    await decks.createDeck(id: 'd1', name: 'Chapter 1');

    service = _StubSyncService(
      decks,
      SupabaseClient('http://localhost:54321', 'test-anon-key'),
      LocalCourseStore(db.db),
      LocalStudyStore(db.db),
      ConnectivityService(Connectivity()), // isOnline() → true in a VM test
    );
    addTearDown(service.dispose);
  });

  test('a pass that drains nothing reports failed and arms the backoff',
      () async {
    await service.syncPending();

    expect(service.pushDecksCalls, 1);
    expect(service.lastOutcome.kind, SyncOutcomeKind.failed);
    expect(service.nextAllowedAt, isNotNull);
  });

  test('syncPending is a no-op inside the backoff window after a failure',
      () async {
    await service.syncPending(); // fails, arms backoff
    await service.syncPending(); // within the window → returns early

    expect(service.pushDecksCalls, 1);
  });

  test('force bypasses the backoff window', () async {
    await service.syncPending();
    await service.syncPending(force: true);

    expect(service.pushDecksCalls, 2);
  });

  test('a clean run reports ok and clears the backoff', () async {
    await service.syncPending(); // fails, arms backoff
    service.drain = true;
    await service.syncPending(force: true); // now drains

    expect(service.lastOutcome.kind, SyncOutcomeKind.ok);
    expect(service.nextAllowedAt, isNull);
  });

  test('the outcome stream emits running then a terminal state', () async {
    final seen = <SyncOutcomeKind>[];
    final sub = service.outcomes.listen((o) => seen.add(o.kind));
    addTearDown(sub.cancel);

    await service.syncPending();
    await Future<void>.delayed(Duration.zero);

    expect(seen, [SyncOutcomeKind.running, SyncOutcomeKind.failed]);
  });
}
