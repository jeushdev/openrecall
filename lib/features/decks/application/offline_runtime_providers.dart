import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/local_db/local_db_providers.dart';
import '../../courses/domain/course.dart';
import '../data/supabase_deck_repository.dart';
import '../domain/card.dart';
import '../domain/deck.dart';
import '../domain/deck_repository.dart';
import '../domain/offline_download.dart';
import 'offline_deck_service.dart';

final offlineDownloadSourceProvider = Provider<OfflineDownloadSource>((ref) {
  try {
    return SupabaseDeckRepository(Supabase.instance.client);
  } catch (_) {
    return const _UnavailableOfflineDownloadSource();
  }
});

final offlinePackageOperationRegistryProvider = Provider((ref) {
  return OfflinePackageOperationRegistry();
});

final offlineDeckCommitBusProvider = Provider<OfflineDeckCommitBus>((ref) {
  final bus = OfflineDeckCommitBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final offlineDeckCommitRevisionProvider =
    NotifierProvider.family<OfflineDeckCommitRevision, int, String>(
      OfflineDeckCommitRevision.new,
    );

class OfflineDeckCommitRevision extends Notifier<int> {
  OfflineDeckCommitRevision(this.deckId);

  final String deckId;

  @override
  int build() {
    final subscription = ref
        .watch(offlineDeckCommitBusProvider)
        .events
        .where((event) => event.deckId == deckId)
        .listen((_) => state++);
    ref.onDispose(subscription.cancel);
    return 0;
  }
}

final offlineDeckServiceProvider = Provider<OfflineDeckService>((ref) {
  final service = OfflineDeckService(
    local: ref.watch(localDeckStoreProvider),
    source: ref.watch(offlineDownloadSourceProvider),
    operations: ref.watch(offlinePackageOperationRegistryProvider),
    isOnline: ref.watch(connectivityServiceProvider).isOnline,
    commitBus: ref.watch(offlineDeckCommitBusProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final offlineDeckRefreshCoordinatorProvider =
    Provider<OfflineDeckRefreshCoordinator>((ref) {
      final coordinator = OfflineDeckRefreshCoordinator(
        ref.watch(offlineDeckServiceProvider),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

class OfflineDeckRefreshCoordinator {
  OfflineDeckRefreshCoordinator(this._service);

  final OfflineDeckService _service;
  final Map<String, _ObservedDeck> _observed = <String, _ObservedDeck>{};

  void attach(String deckId) {
    final state = _observed.putIfAbsent(deckId, _ObservedDeck.new);
    state.pendingRemoval?.cancel();
    state.pendingRemoval = null;
    state.listeners++;
  }

  void reportStatus(String deckId, bool online) {
    final state = _observed[deckId];
    if (state == null || state.listeners == 0) return;
    final reconnect = state.previousOnline == false && online;
    final shouldRefresh = online && (!state.attemptedForAccess || reconnect);
    state.previousOnline = online;
    if (!shouldRefresh) return;
    state.attemptedForAccess = true;
    unawaited(_service.refresh(deckId));
  }

  void detach(String deckId) {
    final state = _observed[deckId];
    if (state == null) return;
    if (state.listeners > 0) state.listeners--;
    if (state.listeners != 0 || state.pendingRemoval != null) return;
    // Dependency graphs release and reacquire the observation provider while
    // applying a commit publication. Defer the zero-listener decision by one
    // event-loop turn so that recomputation remains the same access, while a
    // genuinely closed route is removed before a later user access.
    state.pendingRemoval = Timer(Duration.zero, () {
      final current = _observed[deckId];
      if (!identical(current, state) || state.listeners != 0) return;
      _observed.remove(deckId);
      _service.cancelAutomaticRefresh(deckId);
    });
  }

  void dispose() {
    for (final state in _observed.values) {
      state.pendingRemoval?.cancel();
    }
    for (final deckId in _observed.keys) {
      _service.cancelAutomaticRefresh(deckId);
    }
    _observed.clear();
  }
}

class _ObservedDeck {
  int listeners = 0;
  bool? previousOnline;
  bool attemptedForAccess = false;
  Timer? pendingRemoval;
}

/// One shared observation per deck, regardless of whether Detail, Card List,
/// or pre-session mode selection is consuming it. It fires once for initial
/// online access and once per distinct offline-to-online edge while observed.
final offlineDeckObservationProvider = Provider.autoDispose
    .family<void, String>((ref, deckId) {
      if (!ref.watch(localStorageAvailableProvider)) return;
      OfflineDeckRefreshCoordinator coordinator;
      try {
        coordinator = ref.watch(offlineDeckRefreshCoordinatorProvider);
      } catch (_) {
        // Unit graphs and online-only runtimes may not initialize Supabase.
        return;
      }

      coordinator.attach(deckId);
      ref.listen<AsyncValue<bool>>(onlineStatusProvider, (previous, next) {
        final online = next.asData?.value;
        if (online == null) return;
        coordinator.reportStatus(deckId, online);
      }, fireImmediately: true);

      ref.onDispose(() => coordinator.detach(deckId));
    });

class _UnavailableOfflineDownloadSource implements OfflineDownloadSource {
  const _UnavailableOfflineDownloadSource();

  Never _unavailable() => throw StateError('Supabase is not initialized');

  @override
  Future<int> countCards(String deckId) async => _unavailable();

  @override
  Future<Course?> fetchCourse(String courseId) async => _unavailable();

  @override
  Future<Deck?> fetchDeck(String deckId) async => _unavailable();

  @override
  Future<List<FlashCard>> fetchCardsPage(
    String deckId, {
    required int offset,
    required int limit,
  }) async => _unavailable();
}
