import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Width at or above which the web build renders inside a centered phone-width
/// frame instead of full-bleed. Below it, a phone-sized browser window gets the
/// normal layout (spec-web-mvp §5.2).
const double kWebFrameBreakpoint = 600.0;

/// The content column width used above [kWebFrameBreakpoint] — a large phone.
const double kWebFrameContentWidth = 430.0;

/// Constrains the app to a centered phone-width column on wide web viewports
/// (spec-web-mvp §5.2). The web build is phone-first; this is not a responsive
/// desktop layout, just a frame so the UI isn't stretched across a monitor.
///
/// A no-op unless [enabled] (defaults to [kIsWeb]) and the viewport is at least
/// [kWebFrameBreakpoint] wide. Wrapped around the router content in
/// `lib/app.dart`, inside the `MaterialApp.router` builder.
class WebAppFrame extends StatelessWidget {
  const WebAppFrame({super.key, required this.child, this.enabled = kIsWeb});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    if (MediaQuery.sizeOf(context).width < kWebFrameBreakpoint) return child;

    final tokens = Theme.of(context).extension<AppTokens>()!;
    return ColoredBox(
      color: tokens.mutedFill,
      child: Center(
        child: ClipRect(
          child: SizedBox(width: kWebFrameContentWidth, child: child),
        ),
      ),
    );
  }
}
