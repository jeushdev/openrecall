import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/auth/domain/offline_session_grace.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AuthState _signedOut(SignOutReason? reason) =>
    AuthState(AuthChangeEvent.signedOut, null, signOutReason: reason);

void main() {
  test('a session-expired sign-out while offline keeps the user in', () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.sessionExpired), offline: true);
    expect(grace.isActive, isTrue);
  });

  test('a session-missing sign-out while offline keeps the user in', () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.sessionMissing), offline: true);
    expect(grace.isActive, isTrue);
  });

  test('the same sign-out while online signs the user out', () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.sessionExpired), offline: false);
    expect(grace.isActive, isFalse);
  });

  test('a user-initiated sign-out is never graced, even offline', () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.userInitiated), offline: true);
    expect(grace.isActive, isFalse);
  });

  test('a later event carrying a session clears the grace', () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.sessionExpired), offline: true);
    expect(grace.isActive, isTrue);

    grace.onAuthState(
      AuthState(AuthChangeEvent.tokenRefreshed, _fakeSession()),
      offline: false,
    );
    expect(grace.isActive, isFalse);
  });

  test('clear() drops the grace before the deliberate sign-out event arrives',
      () {
    final grace = OfflineSessionGrace()
      ..onAuthState(_signedOut(SignOutReason.sessionExpired), offline: true)
      ..clear();
    expect(grace.isActive, isFalse);
  });
}

Session _fakeSession() => Session(
      accessToken: 'a',
      tokenType: 'bearer',
      user: User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime(2026).toIso8601String(),
      ),
    );
