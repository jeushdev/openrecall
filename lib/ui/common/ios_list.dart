import 'package:flutter/material.dart';

import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';
import 'app_card.dart';

/// A grouped-inset list section (ui-spec-v5 §5.3): the iOS Settings pattern —
/// an optional uppercased [header], an [AppCard]-backed stack of [IosRow]s with
/// hairline dividers between (not after) them, and an optional [footer]. The
/// section owns its 16px horizontal screen inset.
class IosSection extends StatelessWidget {
  const IosSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 52,
            color: tokens.borderHairline,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                header!.toUpperCase(),
                style: AppType.caption.copyWith(
                  letterSpacing: 0.5,
                  color: tokens.textSecondary,
                ),
              ),
            ),
          AppCard(
            radius: AppRadii.section,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                footer!,
                style: AppType.caption.copyWith(color: tokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single 44-min-height row inside an [IosSection].
class IosRow extends StatelessWidget {
  const IosRow({
    super.key,
    this.leading,
    required this.title,
    this.trailingValue,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.destructive = false,
  });

  final Widget? leading;
  final String title;
  final String? trailingValue;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          if (leading != null) ...[
            SizedBox(
              width: 28,
              height: 28,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: leading,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  title,
                  style: AppType.bodyLarge.copyWith(
                    color: destructive ? tokens.accent('red').text : null,
                  ),
                ),
                if (trailingValue != null)
                  Text(
                    trailingValue!,
                    style: AppType.body.copyWith(color: tokens.textSecondary),
                  ),
                ?trailing,
              ],
            ),
          ),
          if (showChevron)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: tokens.textTertiary,
              ),
            ),
        ],
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: onTap == null
          ? row
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                highlightColor: tokens.mutedFill,
                splashColor: tokens.mutedFill,
                child: row,
              ),
            ),
    );
  }
}

/// The iOS Settings badge: a 28×28 [color]-filled rounded square with a white
/// 16px [icon]. Pass into [IosRow.leading].
class IosRowIcon extends StatelessWidget {
  const IosRowIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}
