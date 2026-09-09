import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../local_db/local_db_providers.dart';
import 'sync_service.dart';
import '../../features/home/application/home_providers.dart';
import '../../features/decks/application/offline_runtime_providers.dart';
import '../../features/stats/application/stats_providers.dart';

void _invalidateSessionReads(Ref ref) {
  ref.invalidate(recentCompletedSessionsProvider);
  ref.invalidate(completedSessionsProvider);
  ref.invalidate(activeSessionProgressProvider);
  ref.invalidate(sessionCountsByDeckProvider);
}

/// The reconnect sync engine, or `null` when Supabase has not been initialized
/// (which is the case in unit tests that build this graph without going through
/// `main()`).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return null;
  }
  final service = SyncService(
    client,
    ref.watch(localDeckStoreProvider),
    ref.watch(localCourseStoreProvider),
    ref.watch(localStudyStoreProvider),
    ref.watch(connectivityServiceProvider),
    isCurrent: ref.watch(localDeckStoreProvider).isCurrent,
    commitBus: ref.watch(offlineDeckCommitBusProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// The last reconnect-sync outcome (milestone E3), for the retry affordance on
/// `SyncStatusChip`. An empty stream when Supabase is not initialized (tests).
final syncOutcomeProvider = StreamProvider<SyncOutcome>((ref) {
  final service = ref.watch(syncServiceProvider);
  if (service == null) return const Stream<SyncOutcome>.empty();
  return service.outcomes;
});

/// A one-shot manual sync that bypasses the reconnect backoff — the tap target
/// on [SyncStatusChip] when writes are queued (milestone E3). Refreshes the
/// pending-count providers once it settles so the chip updates.
final manualSyncProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(syncServiceProvider)?.syncPending(force: true);
    ref.invalidate(pendingSyncProvider);
    ref.invalidate(pendingSyncCountProvider);
    _invalidateSessionReads(ref);
  };
});

/// Keeps a sync-on-reconnect subscription alive for the life of the app: every
/// time connectivity flips to online (including the initial reading at startup),
/// a batched push of the unsynced local rows is kicked off. Watched once by the
/// root widget so it is never disposed mid-session.
final syncCoordinatorProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(onlineStatusProvider, (previous, next) {
    if (next.asData?.value == true) {
      // The connectivity flip alone recomputes the pending providers before the
      // push has drained the queue, so refresh them again once it finishes to
      // clear the O4 chip.
      ref.read(syncServiceProvider)?.syncPending().then((_) {
        ref.invalidate(pendingSyncProvider);
        ref.invalidate(pendingSyncCountProvider);
        _invalidateSessionReads(ref);
      });
    }
  }, fireImmediately: true);
});

/// Whether the local mirror is holding any write that hasn't reached Supabase
/// yet — an offline mastery edit, or a session / session-card row from a
/// fully-offline run. The Profile tab's sign-out dialog reads this so it can
/// warn before the session (and the device-local rows with it) is cleared
/// (ui-spec-v1 §6.4).
///
/// `false` when there is no local database at all (online-only install —
/// nothing is ever queued locally).
///
/// Since spec-v4 (offline-first authoring) this also covers queued content:
/// offline-created / renamed courses and decks, offline-authored or -edited
/// cards, and course / deck / card tombstones.
final pendingSyncProvider = FutureProvider<bool>((ref) async {
  // Recompute when connectivity flips — that's when the queue drains.
  ref.watch(onlineStatusProvider);
  final deckLocal = ref.watch(localDeckStoreProvider);
  final studyLocal = ref.watch(localStudyStoreProvider);
  final courseLocal = ref.watch(localCourseStoreProvider);
  if (deckLocal.isNoop && studyLocal.isNoop && courseLocal.isNoop) return false;

  if ((await courseLocal.unsyncedCourses()).isNotEmpty) return true;
  if ((await deckLocal.unsyncedDecks()).isNotEmpty) return true;
  if ((await deckLocal.contentDirtyCards()).isNotEmpty) return true;
  if ((await deckLocal.unsyncedCards()).isNotEmpty) return true;
  if ((await studyLocal.unsyncedSessions()).isNotEmpty) return true;
  if ((await studyLocal.unsyncedSessionCards()).isNotEmpty) return true;
  if ((await courseLocal.courseDeletions()).isNotEmpty) return true;
  if ((await deckLocal.deckDeletions()).isNotEmpty) return true;
  if ((await deckLocal.cardDeletions()).isNotEmpty) return true;
  return false;
});

/// The total number of local rows still waiting to reach Supabase — the count
/// shown on the O4 `☁ offline · N` chip. Sums every queue [pendingSyncProvider]
/// consults. `0` when there is no local database.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  ref.watch(onlineStatusProvider);
  final deckLocal = ref.watch(localDeckStoreProvider);
  final studyLocal = ref.watch(localStudyStoreProvider);
  final courseLocal = ref.watch(localCourseStoreProvider);
  if (deckLocal.isNoop && studyLocal.isNoop && courseLocal.isNoop) return 0;

  final counts = await Future.wait<int>([
    courseLocal.unsyncedCourses().then((r) => r.length),
    deckLocal.unsyncedDecks().then((r) => r.length),
    deckLocal.contentDirtyCards().then((r) => r.length),
    deckLocal.unsyncedCards().then((r) => r.length),
    studyLocal.unsyncedSessions().then((r) => r.length),
    studyLocal.unsyncedSessionCards().then((r) => r.length),
    courseLocal.courseDeletions().then((r) => r.length),
    deckLocal.deckDeletions().then((r) => r.length),
    deckLocal.cardDeletions().then((r) => r.length),
  ]);
  return counts.fold<int>(0, (sum, n) => sum + n);
});
