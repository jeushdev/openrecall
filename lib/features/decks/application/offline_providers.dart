import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/local_db_providers.dart';
import '../domain/offline_download.dart';
import 'offline_runtime_providers.dart';

export 'offline_runtime_providers.dart';

/// Whether this runtime has the native SQLite mirror needed for deck packages.
/// Web and database-open failures stay online-only.
final offlineStorageAvailableProvider = Provider<bool>(
  (ref) => !ref.watch(localDeckStoreProvider).isNoop,
);

/// The ids of the decks the user has pinned "keep available offline" on this
/// device (spec §10 — a device-local preference, not synced app data).
///
/// Reads the coordinated `is_pinned = 1 AND cards_complete = 1` state, not row
/// existence: `refreshDeckMeta` writes a header row for every listed deck.
/// Empty when there is no local database.
final offlineDeckIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(localDeckStoreProvider).pinnedDeckIds();
});

/// The ids of decks whose full card set is explicitly verified complete. This
/// includes valid empty decks and excludes metadata-only and legacy rows.
final studiableOfflineDeckIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(localDeckStoreProvider).completeCardDeckIds();
});

/// Durable, typed package state for a single deck. This is reconstructed from
/// SQLite and therefore remains authoritative after a process restart.
final offlinePackageStatusProvider =
    FutureProvider.family<OfflinePackageStatus, String>((ref, deckId) {
      ref.watch(offlineDeckCommitRevisionProvider(deckId));
      return ref.watch(localDeckStoreProvider).packageStatus(deckId);
    });

/// Whether deck [deckId] holds local work not yet synced to Supabase. The
/// "Keep available offline" toggle reads this so it can explain that pending
/// work will be retained until it is safely synced.
final deckHasUnsyncedWorkProvider = FutureProvider.family<bool, String>((
  ref,
  deckId,
) {
  return ref.watch(localDeckStoreProvider).deckHasUnsyncedWork(deckId);
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

/// The deck currently being changed by the explicit offline controller. This
/// keeps route presentation scoped to that deck even though the controller is
/// shared app-wide.
final offlineOperationDeckIdProvider =
    NotifierProvider<OfflineOperationDeckIdController, String?>(
      OfflineOperationDeckIdController.new,
    );

class OfflineOperationDeckIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String? deckId) => state = deckId;
}

/// Drives the "Available offline" switch on the Deck Overview: `isLoading`
/// disables it while a download/removal is in flight, `AsyncError` feeds a
/// SnackBar. Holds no value of its own.
final offlineControllerProvider =
    AsyncNotifierProvider<OfflineController, void>(OfflineController.new);

class OfflineController extends AsyncNotifier<void> {
  int _presentationGeneration = 0;

  @override
  FutureOr<void> build() {}

  /// Pins [deckId] "available offline" and mirrors its cards, paging the fetch
  /// so a large deck shows determinate progress (design spec §E.2). Requires
  /// connectivity — the cards come fresh from Supabase.
  Future<void> download(String deckId, String deckName) async {
    final generation = ++_presentationGeneration;
    state = const AsyncLoading<void>();
    ref.read(offlineOperationDeckIdProvider.notifier).report(deckId);
    final progress = ref.read(downloadProgressProvider.notifier);
    final result = await AsyncValue.guard(() async {
      await ref
          .read(offlineDeckServiceProvider)
          .download(
            deckId,
            pin: true,
            onProgress: (value) {
              if (generation == _presentationGeneration) {
                progress.report(value);
              }
            },
          );
    });
    if (generation != _presentationGeneration) return;
    state = result;
    progress.report(null);
    _refreshLocal(deckId);
  }

  /// Re-fetches [deckId] and refreshes its card mirror in place — the manual
  /// "Update offline copy" action (design spec §E.2). Non-clobbering:
  /// [LocalDeckStore.mirrorCards] keeps any `is_synced = 0` row, so unsynced
  /// offline edits survive. Does not change the pin.
  Future<void> updateOfflineCopy(String deckId) async {
    final generation = ++_presentationGeneration;
    state = const AsyncLoading<void>();
    ref.read(offlineOperationDeckIdProvider.notifier).report(deckId);
    final progress = ref.read(downloadProgressProvider.notifier);
    final result = await AsyncValue.guard(() async {
      await ref
          .read(offlineDeckServiceProvider)
          .download(
            deckId,
            pin: false,
            onProgress: (value) {
              if (generation == _presentationGeneration) {
                progress.report(value);
              }
            },
          );
    });
    if (generation != _presentationGeneration) return;
    state = result;
    progress.report(null);
    _refreshLocal(deckId);
  }

  /// Unpins [deckId] and cleans only cards that are safe to discard. History,
  /// pending work, and cards needed by an active session remain intact.
  Future<void> remove(String deckId) async {
    final generation = ++_presentationGeneration;
    state = const AsyncLoading<void>();
    ref.read(offlineOperationDeckIdProvider.notifier).report(deckId);
    ref.read(downloadProgressProvider.notifier).report(null);
    final result = await AsyncValue.guard(
      () => ref.read(offlineDeckServiceProvider).remove(deckId),
    );
    if (generation != _presentationGeneration) return;
    state = result;
    _refreshLocal(deckId);
  }

  void _refreshLocal(String deckId) {
    ref.invalidate(offlineDeckIdsProvider);
    ref.invalidate(studiableOfflineDeckIdsProvider);
    ref.invalidate(offlinePackageStatusProvider(deckId));
  }
}
