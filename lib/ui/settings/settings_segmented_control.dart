import 'package:flutter/material.dart';

import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';

/// One choice in a [SettingsSegmentedControl].
typedef SegmentOption<T> = ({T value, String label});

/// A hand-built segmented pill selector matching the app's token palette
/// (ui-spec-v1 §3.1, §6.5) — an inactive `mutedFill` track with the selected
/// segment lifted onto a hairline-bordered `cardFill` pill.
///
/// The Decks tab's `DeckSegmentedControl` is the same recipe but hard-wired to
/// its own enum; this one is generic so Settings can reuse it for both the
/// Card transition and Progress indicator toggles.
class SettingsSegmentedControl<T> extends StatelessWidget {
  const SettingsSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: AppRadii.gridTileRadius,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in options)
              Expanded(
                child: _Segment(
                  label: option.label,
                  selected: option.value == value,
                  onTap: () => onChanged(option.value),
                  tokens: tokens,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? tokens.cardFill : null,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: tokens.borderHairline,
                  width: AppBorders.hairline,
                )
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? tokens.textPrimary : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
