import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../local_db/local_db_providers.dart';
import 'sync_service.dart';

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
  return SyncService(
    client,
    ref.watch(localDeckStoreProvider),
    ref.watch(localStudyStoreProvider),
    ref.watch(connectivityServiceProvider),
  );
});

/// Keeps a sync-on-reconnect subscription alive for the life of the app: every
/// time connectivity flips to online (including the initial reading at startup),
/// a batched push of the unsynced local rows is kicked off. Watched once by the
/// root widget so it is never disposed mid-session.
final syncCoordinatorProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<bool>>(onlineStatusProvider, (previous, next) {
    if (next.asData?.value == true) {
      ref.read(syncServiceProvider)?.syncPending();
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
final pendingSyncProvider = FutureProvider<bool>((ref) async {
  final deckLocal = ref.watch(localDeckStoreProvider);
  final studyLocal = ref.watch(localStudyStoreProvider);
  if (deckLocal.isNoop && studyLocal.isNoop) return false;

  if ((await deckLocal.unsyncedCards()).isNotEmpty) return true;
  if ((await studyLocal.unsyncedSessions()).isNotEmpty) return true;
  if ((await studyLocal.unsyncedSessionCards()).isNotEmpty) return true;
  return false;
});
