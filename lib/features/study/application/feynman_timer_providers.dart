import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/feynman_timer_preference.dart';

/// Device-local store for the last-used Feynman timer preset (ui-spec-v1
/// §6.2.1, §6.5).
final feynmanTimerPreferenceProvider = Provider<FeynmanTimerPreference>((ref) {
  return FeynmanTimerPreference();
});

/// The most recent Feynman timer preset in seconds, or `null` if the user has
/// never run a Feynman session on this device. Read by the Settings screen as
/// information only. A storage failure surfaces as `null` rather than an error.
final lastFeynmanTimerProvider = FutureProvider<int?>((ref) async {
  try {
    return await ref.watch(feynmanTimerPreferenceProvider).lastUsedSeconds();
  } catch (_) {
    return null;
  }
});
