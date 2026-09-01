import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../data/supabase_deck_repository.dart';
import '../domain/card.dart';
import '../domain/deck_repository.dart';
import '../domain/offline_download.dart';
import 'deck_providers.dart';

/// The ids of the decks the user has pinned "keep available offline" on this
/// device (spec §10 — a device-local preference, not synced app data).
///
/// Reads `is_pinned`, not row existence: since spec-v4 `refreshDeckMeta` writes
/// a header row for *every* deck, so `downloadedDeckIds()` would show the Deck
/// Overview switch as on for every deck the user has ever seen listed. Empty
/// when there is no local database.
final offlineDeckIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(localDeckStoreProvider).pinnedDeckIds();
});

/// The ids of decks whose cards are mirrored locally — the ones actually
/// studiable with no connection (milestone E1). Everything else renders locked
/// while offline.
final studiableOfflineDeckIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(localDeckStoreProvider).mirroredCardDeckIds();
});

/// Whether deck [deckId] holds local work not yet synced to Supabase. The
/// "Keep available offline" toggle reads this to decide whether unpinning needs
/// a data-loss warning (spec-v4 §O4).
final deckHasUnsyncedWorkProvider =
    FutureProvider.family<bool, String>((ref, deckId) {
  return ref.watch(localDeckStoreProvider).deckHasUnsyncedWork(deckId);
});

/// Cards fetched per network round-trip during a download. Large enough that a
/// small deck is one page, small enough that the progress bar moves on a big one.
const int kDownloadPageSize = 100;

/// The Supabase-backed card source a download pages through. A concrete
/// [SupabaseDeckRepository] in production; a fake in tests.
final offlineDownloadSourceProvider = Provider<OfflineDownloadSource>((ref) {
  return SupabaseDeckRepository(Supabase.instance.client);
});

/// Determinate progress for the download currently running on the Deck Overview,
/// or `null` when none is. Read by the `OfflineToggle`; written only by
/// [OfflineController].
final downloadProgressProvider =
    NotifierProvider<DownloadProgressController, DownloadProgress?>(
  DownloadProgressController.new,
);

class DownloadProgressController extends Notifier<DownloadProgress?> {
  @override
  DownloadProgress? build() => null;

  void report(DownloadProgress? value) => state = value;
}

/// Drives the "Available offline" switch on the Deck Overview: `isLoading`
/// disables it while a download/removal is in flight, `AsyncError` feeds a
/// SnackBar. Holds no value of its own.
final offlineControllerProvider =
    AsyncNotifierProvider<OfflineController, void>(OfflineController.new);

class OfflineController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Pins [deckId] "available offline" and mirrors its cards, paging the fetch
  /// so a large deck shows determinate progress (design spec §E.2). Requires
  /// connectivity — the cards come fresh from Supabase.
  Future<void> download(String deckId, String deckName) async {
    state = const AsyncLoading<void>();
    final progress = ref.read(downloadProgressProvider.notifier);
    state = await AsyncValue.guard(() async {
      final cards = await _fetchAllPaged(deckId, progress);
      final local = ref.read(localDeckStoreProvider);
      await local.pinDeck(deckId: deckId, name: deckName);
      await local.mirrorCards(deckId, cards);
    });
    progress.report(null);
    _refresh(deckId);
  }

  /// Re-fetches [deckId] and refreshes its card mirror in place — the manual
  /// "Update offline copy" action (design spec §E.2). Non-clobbering:
  /// [LocalDeckStore.mirrorCards] keeps any `is_synced = 0` row, so unsynced
  /// offline edits survive. Does not change the pin.
  Future<void> updateOfflineCopy(String deckId) async {
    state = const AsyncLoading<void>();
    final progress = ref.read(downloadProgressProvider.notifier);
    state = await AsyncValue.guard(() async {
      final cards = await _fetchAllPaged(deckId, progress);
      await ref.read(localDeckStoreProvider).mirrorCards(deckId, cards);
    });
    progress.report(null);
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

  Future<List<FlashCard>> _fetchAllPaged(
    String deckId,
    DownloadProgressController progress,
  ) async {
    final source = ref.read(offlineDownloadSourceProvider);
    final total = await source.countCards(deckId);
    progress.report(DownloadProgress(done: 0, total: total));
    final all = <FlashCard>[];
    for (var offset = 0; offset < total; offset += kDownloadPageSize) {
      final page = await source.fetchCardsPage(deckId,
          offset: offset, limit: kDownloadPageSize);
      if (page.isEmpty) break;
      all.addAll(page);
      progress.report(DownloadProgress(done: all.length, total: total));
    }
    return all;
  }

  void _refresh(String deckId) {
    ref.invalidate(offlineDeckIdsProvider);
    ref.invalidate(studiableOfflineDeckIdsProvider);
    ref.invalidate(decksProvider);
    ref.invalidate(deckCardsProvider(deckId));
  }
}
