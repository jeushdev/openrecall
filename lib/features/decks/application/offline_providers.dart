import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../data/supabase_deck_repository.dart';
import 'deck_providers.dart';

/// The ids of the decks the user has toggled "available offline" on this device
/// (spec §10 — a device-local preference, not synced app data). Empty when
/// there is no local database.
final offlineDeckIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(localDeckStoreProvider).downloadedDeckIds();
});

/// Whether deck [deckId] holds local work not yet synced to Supabase. The
/// "Keep available offline" toggle reads this to decide whether unpinning needs
/// a data-loss warning (spec-v4 §O4).
final deckHasUnsyncedWorkProvider =
    FutureProvider.family<bool, String>((ref, deckId) {
  return ref.watch(localDeckStoreProvider).deckHasUnsyncedWork(deckId);
});

/// Drives the "Available offline" switch on the Deck Overview: `isLoading`
/// disables it while a download/removal is in flight, `AsyncError` feeds a
/// SnackBar. Holds no value of its own.
final offlineControllerProvider =
    AsyncNotifierProvider<OfflineController, void>(OfflineController.new);

class OfflineController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Downloads [deckId]'s cards into the local mirror. Requires connectivity —
  /// the cards are fetched fresh from Supabase first.
  Future<void> download(String deckId, String deckName) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(() async {
      final remote = SupabaseDeckRepository(Supabase.instance.client);
      final cards = await remote.fetchCards(deckId);
      await ref.read(localDeckStoreProvider).downloadDeck(
            deckId: deckId,
            name: deckName,
            cards: cards,
          );
    });
    _refresh(deckId);
  }

  /// Drops [deckId]'s local footprint. Any unsynced study results it still holds
  /// are lost — the switch's confirm dialog is where that warning belongs.
  Future<void> remove(String deckId) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(localDeckStoreProvider).removeDeck(deckId),
    );
    _refresh(deckId);
  }

  void _refresh(String deckId) {
    ref.invalidate(offlineDeckIdsProvider);
    ref.invalidate(decksProvider);
    ref.invalidate(deckCardsProvider(deckId));
  }
}
