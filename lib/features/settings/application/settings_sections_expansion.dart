import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which Settings-tab sections are currently expanded, keyed by a stable section
/// id (see the `_k*` consts in `settings_tab_screen.dart`).
///
/// Sections are **independent** — expanding one never collapses a sibling — and
/// the state is **never persisted**: it starts empty (all collapsed) and
/// [ScaffoldWithNavBar] calls [collapseAll] on every navigation into the
/// Settings branch, so re-entering the tab always shows a fully collapsed
/// screen (milestone A).
class SettingsSectionsExpansion extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) {
    state = state.contains(id)
        ? ({...state}..remove(id))
        : {...state, id};
  }

  void collapseAll() => state = const {};
}

final settingsSectionsExpansionProvider =
    NotifierProvider<SettingsSectionsExpansion, Set<String>>(
  SettingsSectionsExpansion.new,
);
