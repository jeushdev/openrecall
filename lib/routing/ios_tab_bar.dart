import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_geometry.dart';
import '../theme/app_tokens.dart';
import '../theme/app_type.dart';

/// The standard iOS tab bar (ui-spec-v5 §5.1): a full-width blurred bar in the
/// [Scaffold.bottomNavigationBar] slot carrying the four tab targets (Home,
/// Decks, History, More — ui-spec-v4-navigation §2). Selection is conveyed by
/// colour — [AppTokens.tint] active, [AppTokens.textSecondary] inactive.
///
/// Unlike the superseded glass pill there is no Create button here; card/course
/// creation is launched from the Home and Decks headers now.
class IosTabBar extends StatelessWidget {
  const IosTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
  });

  final int currentIndex;
  final void Function(int index) onSelectTab;

  static const _items = <({String key, IconData icon, String label})>[
    (key: 'nav-home', icon: Icons.home_outlined, label: 'Home'),
    (key: 'nav-decks', icon: Icons.style_outlined, label: 'Decks'),
    (key: 'nav-history', icon: Icons.schedule_outlined, label: 'History'),
    (key: 'nav-more', icon: Icons.more_horiz, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final screenHeight = MediaQuery.of(context).size.height;
    final barHeight = (screenHeight * 0.09).clamp(64.0, 88.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.cardFill.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: tokens.borderHairline, width: AppBorders.hairline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: barHeight,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _TabItem(
                        itemKey: ValueKey(_items[i].key),
                        icon: _items[i].icon,
                        label: _items[i].label,
                        selected: i == currentIndex,
                        onTap: () => onSelectTab(i),
                        tokens: tokens,
                        height: barHeight,
                      ),
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

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.itemKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
    required this.height,
  });

  final Key itemKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.tint : tokens.textSecondary;
    return InkResponse(
      key: itemKey,
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, size: 28, semanticLabel: label, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppType.caption.copyWith(fontSize: 12, height: 1.0, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
