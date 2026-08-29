import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The shell chrome wrapped around the four tab branches
/// (`/decks`, `/mastery`, `/profile`, `/settings`).
///
/// The bottom nav bar is "conditionally rendered" purely by tree structure: it
/// lives here, inside [StatefulShellRoute], and is simply never part of the
/// widget tree for the top-level routes (`/study/:deckId`, `/deck-creator`) —
/// not hidden via opacity/visibility (ui-spec-v1 §4).
///
/// This is a throwaway [NavigationBar]. The real floating glassmorphic pill with
/// the inline Create button is milestone U3 (§5.1).
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
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Decks'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: 'Mastery'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
