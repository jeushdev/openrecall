import 'package:supabase_flutter/supabase_flutter.dart';

/// Decides whether the app should keep treating the user as signed in *after*
/// gotrue has dropped the session.
///
/// It says yes only when the drop was an involuntary "session expired / missing"
/// that happened while the device was offline — the case where a cached token
/// simply could not be refreshed (design spec §E.1: "an expired-token refresh
/// failure must not lock the user out"). A deliberate sign-out, or a drop that
/// happened while online (a genuinely revoked token, a deleted account), clears
/// the grace at once and the user goes back to Login.
///
/// The grace is a stopgap, not a second source of truth: offline the app is
/// read-only against the local mirror and every Supabase write already falls
/// through to the local queue, so honouring a lapsed token costs nothing. The
/// next real auth event — a reconnect that refreshes the session, or one that
/// confirms it is gone — replaces it.
class OfflineSessionGrace {
  bool _active = false;

  /// Whether the lapsed session should still be treated as signed in.
  bool get isActive => _active;

  /// Feed every [AuthState] from `onAuthStateChange`. [offline] is the
  /// connectivity reading at the moment the event arrived.
  void onAuthState(AuthState state, {required bool offline}) {
    if (state.session != null) {
      _active = false;
      return;
    }
    if (state.event == AuthChangeEvent.signedOut) {
      final involuntary =
          state.signOutReason == SignOutReason.sessionExpired ||
          state.signOutReason == SignOutReason.sessionMissing;
      _active = involuntary && offline;
    }
  }

  /// Call the moment the user explicitly asks to sign out, so the `signedOut`
  /// event that follows is never mistaken for an involuntary lapse.
  void clear() => _active = false;
}
