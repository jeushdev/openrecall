import 'package:shared_preferences/shared_preferences.dart';

/// How the Flip-mode card reveals its back (ui-spec-v1 §6.5, §6.2). The default
/// is [flip3d] — the spec lists it first and treats it as the designed
/// interaction. No consumer reads this yet; `FlipCard` still animates a single
/// way until the setting is wired in a later Study-screen change.
enum CardTransition { flip3d, fade }

/// The study session's top progress indicator style (ui-spec-v1 §6.5). Default
/// [hairline] per the spec. Not wired to `StudyProgressBar` yet.
enum ProgressIndicatorStyle { hairline, pill }

/// Device-local store for the "Study appearance" toggles (ui-spec-v1 §6.5).
///
/// Like [NotificationPreferences], these are per-device display choices, not
/// synced app data, so they live in `SharedPreferences` rather than on
/// `profiles`. Same injectable-prefs shape so a test can pass
/// `SharedPreferences.setMockInitialValues`.
class StudyAppearancePreferences {
  StudyAppearancePreferences([SharedPreferences? prefs]) : _injected = prefs;

  static const String _transitionKey = 'card_transition';
  static const String _progressKey = 'progress_indicator';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<CardTransition> cardTransition() async {
    final raw = (await _prefs).getString(_transitionKey);
    for (final v in CardTransition.values) {
      if (v.name == raw) return v;
    }
    return CardTransition.flip3d;
  }

  Future<void> setCardTransition(CardTransition value) async {
    await (await _prefs).setString(_transitionKey, value.name);
  }

  Future<ProgressIndicatorStyle> progressIndicator() async {
    final raw = (await _prefs).getString(_progressKey);
    for (final v in ProgressIndicatorStyle.values) {
      if (v.name == raw) return v;
    }
    return ProgressIndicatorStyle.hairline;
  }

  Future<void> setProgressIndicator(ProgressIndicatorStyle value) async {
    await (await _prefs).setString(_progressKey, value.name);
  }
}
