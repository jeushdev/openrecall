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
