import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] into a [Listenable] for [GoRouter.refreshListenable], so
/// the router re-evaluates its redirect whenever the stream emits.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
          // gotrue pushes token-refresh failures onto `onAuthStateChange`, and
          // offline that happens on every launch with an expired token. With no
          // handler the error escapes as an unhandled zone error. A refresh
          // failure is not a route change — the auth repository's `isSignedIn`
          // already holds the answer (design spec §E.1).
          onError: (_) {},
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
