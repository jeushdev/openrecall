import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_tokens.dart';

/// A titled group of rows on the Settings tab that collapses behind a tappable
/// header (milestone A).
///
/// Presentational only: the caller owns the [expanded] flag and the [onToggle]
/// callback (wired to `settingsSectionsExpansionProvider`). The title weight
/// matches the Mastery tab's `MasterySectionHeader` so the two screens read as
/// one family. Expand / collapse animates with the shared [AppMotion] timing.
class CollapsibleSettingsSection extends StatelessWidget {
  const CollapsibleSettingsSection({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: AppMotion.expandDuration,
                    curve: AppMotion.expandCurve,
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.expandDuration,
          curve: AppMotion.expandCurve,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
