import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A thin read of the device's network state, used to decide when a
/// sync-on-reconnect pass is worth attempting (spec §10).
///
/// `connectivity_plus` reports the network *interface*, not real reachability,
/// so this is only ever a hint: the cache-first repositories fall back to local
/// data by catching a failed Supabase call, not by trusting [isOnline]. On any
/// platform error the service assumes online — the safe default is to try the
/// network and fall back on an actual failure.
class ConnectivityService {
  ConnectivityService(this._connectivity);

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    try {
      return _hasLink(await _connectivity.checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  /// Emits `true`/`false` as the interface comes and goes. Errors are swallowed.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasLink).handleError((_) {});

  static bool _hasLink(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(Connectivity()),
);

/// The current online/offline state as a stream, seeded with an immediate read.
/// Defaults to `true` if the platform channel is unavailable (e.g. in tests).
final onlineStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.isOnline();
  yield* service.onStatusChange;
});
