import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../features/decks/presentation/widgets/create_menu_sheet.dart';
import '../theme/app_tokens.dart';

/// The floating glassmorphic bottom navigation pill (ui-spec-v1 §5.1).
///
/// A safe-area-aware rounded bar carrying the four tab icons (Home, Decks,
/// History, More — ui-spec-v4-navigation §2) plus a central,
/// inline (not elevated) circular Create button. Selection is conveyed by icon
/// colour only — [AppTokens.textPrimary] active, [AppTokens.textTertiary]
/// inactive — with no background highlight.
///
/// Lives in the [Scaffold.bottomNavigationBar] slot of the shell scaffold, which
/// runs `extendBody: true` so the branch content renders behind the pill and the
/// [BackdropFilter] has live content to blur. The bar is never mounted during a
/// Study session (§4, §5.1), so the blur never competes with the study loop for
/// frame budget.
class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
  });

  /// The active shell branch index (0 Home, 1 Decks, 2 History, 3 More).
  final int currentIndex;

  /// Invoked with a branch index when a tab icon is tapped.
  final void Function(int index) onSelectTab;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // A 55% veil of white reads as a floating pill over light content; a 55%
    // veil of `#1E1E1E` over already-dark content does not, so the dark theme
    // leans on a heavier fill to keep the same separation
    // (`docs/spec-v5-dark-mode.md` §6).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassAlpha = isDark ? 0.72 : 0.55;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 18 + bottomInset),
      child: SizedBox(
        height: 66,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // rgba(<cardFill>, 0.55) light / 0.72 dark — see `glassAlpha`.
                color: tokens.cardFill.withValues(alpha: glassAlpha),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  // rgba(26,26,26,0.1): a darker-tinted, low-opacity border so
                  // the glass edge stays visible against light content scrolling
                  // underneath — deliberately not `borderHairline` at full
                  // opacity (§5.1). The base colour is `textPrimary` (#1A1A1A).
                  color: tokens.textPrimary.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  _NavItem(
                    itemKey: const ValueKey('nav-home'),
                    icon: Icons.home_outlined,
                    semanticLabel: 'Home',
                    selected: currentIndex == 0,
                    onTap: () => onSelectTab(0),
                    tokens: tokens,
                  ),
                  _NavItem(
                    itemKey: const ValueKey('nav-decks'),
                    icon: Icons.style_outlined,
                    semanticLabel: 'Decks',
                    selected: currentIndex == 1,
                    onTap: () => onSelectTab(1),
                    tokens: tokens,
                  ),
                  Expanded(
                    child: Center(child: _CreateButton(tokens: tokens)),
                  ),
                  _NavItem(
                    itemKey: const ValueKey('nav-history'),
                    icon: Icons.schedule_outlined,
                    semanticLabel: 'History',
                    selected: currentIndex == 2,
                    onTap: () => onSelectTab(2),
                    tokens: tokens,
                  ),
                  _NavItem(
                    itemKey: const ValueKey('nav-more'),
                    icon: Icons.more_horiz,
                    semanticLabel: 'More',
                    selected: currentIndex == 3,
                    onTap: () => onSelectTab(3),
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single tab icon. Fills an equal share of the bar width; no background
/// highlight — colour alone marks the active tab.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.itemKey,
    required this.icon,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  final Key itemKey;
  final IconData icon;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkResponse(
        key: itemKey,
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          height: double.infinity,
          child: Center(
            child: Icon(
              icon,
              semanticLabel: semanticLabel,
              color: selected ? tokens.textPrimary : tokens.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The inline 48×48 circular Create action, sitting at the same height as the
/// tab icons (not elevated — §5.1). Opens the Create menu bottom sheet
/// ([CreateMenuSheet], ui-spec-v2 §6.1); whichever route it launches is a
/// top-level one, so back-navigation returns to the launching tab.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: tokens.accent('red').fill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('nav-create'),
          onTap: () => CreateMenuSheet.show(context),
          child: Center(
            child: Icon(
              Icons.add,
              semanticLabel: 'Create',
              color: tokens.cardFill,
            ),
          ),
        ),
      ),
    );
  }
}
