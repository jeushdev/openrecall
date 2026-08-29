import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../../notifications/application/notification_providers.dart';
import '../data/notification_preferences.dart';
import '../data/supabase_account_repository.dart';
import '../domain/account_repository.dart';

/// The live repository is backed by the initialized Supabase singleton. Tests
/// override this with a fake, so nothing else in the feature imports `Supabase`.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return SupabaseAccountRepository(Supabase.instance.client);
});

/// Device-local store for the reminders on/off preference.
final notificationPreferencesProvider = Provider<NotificationPreferences>((ref) {
  return NotificationPreferences();
});

/// App name + version string for the About section, e.g. `1.0.0+3`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// The reminders toggle. `build()` reads the persisted preference; [setEnabled]
/// writes it and pushes the new value into the [NotificationService] gate.
final notificationsEnabledProvider =
    AsyncNotifierProvider<NotificationsEnabledController, bool>(
  NotificationsEnabledController.new,
);

class NotificationsEnabledController extends AsyncNotifier<bool> {
  @override
  FutureOr<bool> build() {
    return ref.read(notificationPreferencesProvider).isEnabled();
  }

  Future<void> setEnabled(bool value) async {
    final rollback = state;
    state = AsyncData(value); // Optimistic — the switch follows the tap.
    final result = await AsyncValue.guard(() async {
      await ref.read(notificationPreferencesProvider).setEnabled(value);
      await ref.read(notificationServiceProvider).setEnabled(value);
      return value;
    });
    state = result.hasError ? rollback : result;
  }
}

/// Drives the "Log out" and "Delete account" actions: `isLoading` disables the
/// tiles, `hasError` feeds the SnackBar. Holds no value of its own — it only
/// tracks the in-flight state of the most recent action (mirrors
/// `AuthController` in the auth feature).
final accountActionsProvider =
    AsyncNotifierProvider<AccountActionsController, void>(
  AccountActionsController.new,
);

class AccountActionsController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }

  // Sign-out reuses the auth feature's repository so there is one code path and
  // one thing to fake in tests.
  Future<void> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  Future<void> deleteAccount() {
    return _run(() async {
      await ref.read(accountRepositoryProvider).deleteAccount();
      // The account is gone — clear the device-local reminder preference and
      // drop any pending notification so nothing lingers for the next user.
      await ref.read(notificationPreferencesProvider).setEnabled(true);
      await ref.read(notificationServiceProvider).cancelReturnReminder();
    });
  }
}
