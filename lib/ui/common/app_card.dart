import 'package:flutter/material.dart';

import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';

/// The v5 elevated surface (ui-spec-v5 §3/§4): a token-filled rounded container
/// carrying [AppShadows.card] in light mode and nothing in dark. The one place a
/// BoxShadow is applied at the widget layer.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = AppRadii.card,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: tokens.mutedFill,
          highlightColor: tokens.mutedFill,
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.cardFill,
        borderRadius: br,
        boxShadow: AppShadows.card(Theme.of(context).brightness),
      ),
      child: ClipRRect(borderRadius: br, child: content),
    );
  }
}
