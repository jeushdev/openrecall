import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'glass_bottom_nav_bar.dart';

/// The shell chrome wrapped around the four tab branches
/// (`/decks`, `/mastery`, `/profile`, `/settings`).
///
/// The bottom nav bar is "conditionally rendered" purely by tree structure: it
/// lives here, inside [StatefulShellRoute], and is simply never part of the
/// widget tree for the top-level routes (`/study/:deckId`, `/deck-creator`) —
/// not hidden via opacity/visibility (ui-spec-v1 §4).
///
/// The bar itself is [GlassBottomNavBar] (§5.1). The scaffold runs
/// `extendBody: true` so each branch renders full-height behind the floating
/// pill and its [BackdropFilter] has live content to blur.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again returns it to its initial location.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GlassBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelectTab: _goBranch,
      ),
    );
  }
}
