import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_db_providers.dart';
import 'local_meta_store.dart';

/// Drops the entire local mirror when the signed-in user id changes, so one
/// account never sees another's downloaded decks or pin state (design spec
/// §E.3 — the mirror is a private file, not RLS-protected).
///
/// Watched once by `OpenRecallApp`. A no-op when there is no local database or
/// no Supabase (tests). Sign-*out* is deliberately not handled here — the
/// Profile sign-out dialog already warns about unsynced work, and keeping the
/// mirror across a sign-out / sign-in of the *same* user avoids a needless
/// re-download.
final mirrorScopeGuardProvider = Provider<void>((ref) {
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return;
  final meta = LocalMetaStore(database.db);

  StreamSubscription<AuthState>? sub;
  try {
    final auth = Supabase.instance.client.auth;
    // Seed on first run so a pre-guard install doesn't wipe on its first event.
    final current = auth.currentSession?.user.id;
    if (current != null) {
      meta.lastUserId().then((seen) {
        if (seen == null) meta.setLastUserId(current);
      });
    }
    sub = auth.onAuthStateChange.listen((state) async {
      final uid = state.session?.user.id;
      if (uid == null) return;
      final seen = await meta.lastUserId();
      if (seen != null && seen != uid) {
        await meta.wipeMirror();
      }
      await meta.setLastUserId(uid);
    });
  } catch (_) {
    // No Supabase initialised — nothing to guard.
  }
  ref.onDispose(() => sub?.cancel());
});
