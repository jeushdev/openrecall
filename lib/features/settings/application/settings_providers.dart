import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../../notifications/application/notification_providers.dart';
import '../data/notification_preferences.dart';
import '../data/study_appearance_preferences.dart';
import '../data/supabase_account_repository.dart';
import '../data/theme_mode_preference.dart';
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

/// Device-local store for the "Study appearance" toggles (ui-spec-v1 §6.5).
final studyAppearancePreferencesProvider =
    Provider<StudyAppearancePreferences>((ref) {
  return StudyAppearancePreferences();
});

/// Device-local store for the theme override (`docs/spec-v5-dark-mode.md` §4).
final themeModePreferenceProvider = Provider<ThemeModePreference>((ref) {
  return ThemeModePreference();
});

/// Cold-start seed for [themeModeProvider]. `main()` eagerly reads `theme_mode`
/// from `SharedPreferences` before `runApp` and overrides this with the saved
/// value, so [ThemeModeController.build] can return synchronously and the very
/// first frame paints in the right theme (§4.1). Left `null` in tests and any
/// entrypoint that skips the eager read — the controller then reads the
/// preference asynchronously instead.
final initialThemeModeProvider = Provider<ThemeMode?>((ref) => null);

/// The active theme override — System (default), Light or Dark. `build()`
/// returns the [initialThemeModeProvider] seed synchronously when present,
/// otherwise reads the persisted value and degrades to [ThemeMode.system] on a
/// storage error (mirrors how [StudyAppearanceController] degrades). Writes are
/// optimistic with rollback.
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  ThemeModePreference get _prefs => ref.read(themeModePreferenceProvider);

  @override
  FutureOr<ThemeMode> build() {
    final seed = ref.read(initialThemeModeProvider);
    if (seed != null) return seed;
    return _load();
  }

  Future<ThemeMode> _load() async {
    try {
      return await _prefs.themeMode();
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    final rollback = state;
    state = AsyncData(value); // Optimistic — the pill follows the tap.
    final result = await AsyncValue.guard(() async {
      await _prefs.setThemeMode(value);
      return value;
    });
    state = result.hasError ? rollback : result;
  }
}

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

/// The current "Study appearance" selection (ui-spec-v1 §6.5).
@immutable
class StudyAppearance {
  const StudyAppearance({
    required this.cardTransition,
    required this.progressIndicator,
    required this.cardFontSize,
  });

  static const StudyAppearance defaults = StudyAppearance(
    cardTransition: CardTransition.flip3d,
    progressIndicator: ProgressIndicatorStyle.hairline,
    cardFontSize: CardFontSize.medium,
  );

  final CardTransition cardTransition;
  final ProgressIndicatorStyle progressIndicator;
  final CardFontSize cardFontSize;

  StudyAppearance copyWith({
    CardTransition? cardTransition,
    ProgressIndicatorStyle? progressIndicator,
    CardFontSize? cardFontSize,
  }) {
    return StudyAppearance(
      cardTransition: cardTransition ?? this.cardTransition,
      progressIndicator: progressIndicator ?? this.progressIndicator,
      cardFontSize: cardFontSize ?? this.cardFontSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StudyAppearance &&
      other.cardTransition == cardTransition &&
      other.progressIndicator == progressIndicator &&
      other.cardFontSize == cardFontSize;

  @override
  int get hashCode =>
      Object.hash(cardTransition, progressIndicator, cardFontSize);
}

/// Reads the persisted "Study appearance" toggles and writes them back on
/// change. `build()` swallows a storage failure and returns
/// [StudyAppearance.defaults] so the Settings toggles always render at a sane
/// position (mirrors how the notification toggle degrades). Writes are
/// optimistic with rollback on error, like [NotificationsEnabledController].
final studyAppearanceProvider =
    AsyncNotifierProvider<StudyAppearanceController, StudyAppearance>(
  StudyAppearanceController.new,
);

class StudyAppearanceController extends AsyncNotifier<StudyAppearance> {
  StudyAppearancePreferences get _prefs =>
      ref.read(studyAppearancePreferencesProvider);

  @override
  Future<StudyAppearance> build() async {
    try {
      return StudyAppearance(
        cardTransition: await _prefs.cardTransition(),
        progressIndicator: await _prefs.progressIndicator(),
        cardFontSize: await _prefs.cardFontSize(),
      );
    } catch (_) {
      return StudyAppearance.defaults;
    }
  }

  Future<void> setCardTransition(CardTransition value) async {
    await _update(
      (a) => a.copyWith(cardTransition: value),
      () => _prefs.setCardTransition(value),
    );
  }

  Future<void> setProgressIndicator(ProgressIndicatorStyle value) async {
    await _update(
      (a) => a.copyWith(progressIndicator: value),
      () => _prefs.setProgressIndicator(value),
    );
  }

  Future<void> setCardFontSize(CardFontSize value) async {
    await _update(
      (a) => a.copyWith(cardFontSize: value),
      () => _prefs.setCardFontSize(value),
    );
  }

  Future<void> _update(
    StudyAppearance Function(StudyAppearance) next,
    Future<void> Function() persist,
  ) async {
    final rollback = state;
    final current = state.asData?.value ?? StudyAppearance.defaults;
    state = AsyncData(next(current)); // Optimistic — the pill follows the tap.
    final result = await AsyncValue.guard(() async {
      await persist();
      return next(current);
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
