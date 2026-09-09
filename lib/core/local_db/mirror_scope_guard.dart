import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/application/profile_providers.dart';
import '../../features/decks/application/offline_runtime_providers.dart';
import '../../features/study/application/session_controller.dart';
import '../sync/sync_providers.dart';
import 'local_db_providers.dart';

final accountScopeIdentityProvider = StreamProvider<String?>((ref) async* {
  try {
    final auth = Supabase.instance.client.auth;
    yield auth.currentUser?.id;
    yield* auth.onAuthStateChange
        .map((event) => event.session?.user.id)
        .distinct();
  } catch (_) {
    yield null;
  }
});

/// Local-only barrier: revoke old DAO handles before clearing the mirror.
final mirrorScopeGuardProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return;
  final uid = await ref.watch(accountScopeIdentityProvider.future);
  if (!ref.mounted) return;
  if (uid == null) return; // Offline auth grace retains the local owner.
  final generation = database.scopeGeneration;
  ref.invalidate(syncServiceProvider);
  await database.scopeAccount(uid);
  if (database.scopeGeneration != generation) {
    if (!ref.mounted) return;
    ref.invalidate(localDeckStoreProvider);
    ref.invalidate(offlineDeckServiceProvider);
    ref.invalidate(offlinePackageOperationRegistryProvider);
    ref.invalidate(localCourseStoreProvider);
    ref.invalidate(localStudyStoreProvider);
    ref.invalidate(localStatsStoreProvider);
    ref.invalidate(applicationCacheProvider);
    ref.invalidate(userIdentityProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(sessionControllerProvider);
    ref.invalidate(syncCoordinatorProvider);
  }
});
