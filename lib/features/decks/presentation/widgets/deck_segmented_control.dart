import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../deck_segment.dart';

/// The Due / All segmented toggle at the top of the Decks tab (ui-spec-v1 §6.1).
///
/// Built by hand rather than with `ToggleButtons` / `CupertinoSegmentedControl`
/// so it matches the app's token palette exactly: an inactive [AppTokens.mutedFill]
/// track (§3.1) with the selected segment lifted onto a hairline-bordered
/// [AppTokens.cardFill] pill.
class DeckSegmentedControl extends StatelessWidget {
  const DeckSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DeckSegment value;
  final ValueChanged<DeckSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.mutedFill,
        borderRadius: AppRadii.gridTileRadius,
      ),
      child: Row(
        children: [
          for (final segment in DeckSegment.values)
            Expanded(
              child: _Segment(
                label: segment.label,
                selected: segment == value,
                onTap: () => onChanged(segment),
                tokens: tokens,
              ),
            ),
        ],
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
