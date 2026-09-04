import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';

/// An iOS large-title screen shell (ui-spec-v5 §5.2): a [Scaffold] over a
/// [CustomScrollView] whose leading sliver is a pinned, flat [SliverAppBar]
/// carrying a [FlexibleSpaceBar] title that scales from the collapsed inline
/// size ([AppType.headline]) up to large-title size when expanded.
///
/// Callers supply [slivers] directly — wrap plain child lists in a
/// `SliverPadding(padding: contentPadding, sliver: SliverList.list(children: ...))`.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.slivers,
    this.leading,
    this.headerBackground,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 120),
  });

  final String title;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? leading;
  final Widget? headerBackground;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: tokens.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: tokens.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            expandedHeight: 84,
            leading: leading,
            actions: actions,
            flexibleSpace: FlexibleSpaceBar(
              background: headerBackground,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 0),
              expandedTitleScale: 46 / 28,
              title: Text(title, style: AppType.headline),
            ),
          ),
          ...slivers,
        ],
      ),
    );
  }
}