import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/app_type.dart';
import 'navigation_obstruction.dart';

/// An iOS large-title screen shell (ui-spec-v5 §5.2): a [Scaffold] over a
/// [CustomScrollView] whose leading sliver is a pinned, flat [SliverAppBar]
/// carrying a [FlexibleSpaceBar] title that scales from the collapsed inline
/// size ([AppType.headline]) up to large-title size when expanded.
///
/// Callers supply [slivers] directly and own their horizontal/top spacing. The
/// scaffold adds the bottom scroll clearance required by the enclosing tab
/// shell, or the system bottom inset when it is used on a standalone route.
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.slivers,
    this.leading,
    this.headerBackground,
    this.backgroundDecoration,
  });

  final String title;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? leading;
  final Widget? headerBackground;
  final Widget? backgroundDecoration;

  static const double _bottomGap = 16;
  static const double _horizontalTitlePadding = 24;
  static const double _headerBottomPadding = 8;
  static const double _minimumCollapsedHeight = 56;
  static const double _minimumExpandedHeight = 84;

  double _textHeight(
    BuildContext context,
    String value,
    TextStyle style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  double _textWidth(
    BuildContext context,
    String value,
    TextStyle style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: maxWidth);
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final mediaQuery = MediaQuery.of(context);
    final inheritedObstruction = NavigationObstruction.maybeBottomOf(context);
    final bottomClearance =
        (inheritedObstruction > 0
            ? inheritedObstruction
            : mediaQuery.viewPadding.bottom) +
        _bottomGap;
    final automaticLeading = leading == null && Navigator.of(context).canPop()
        ? const BackButton()
        : null;
    final effectiveLeading = leading ?? automaticLeading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final leadingWidth = effectiveLeading == null ? 0.0 : 56.0;
        final contentWidth =
            (constraints.maxWidth - _horizontalTitlePadding - 16 - leadingWidth)
                .clamp(1.0, double.infinity);
        final scale = mediaQuery.textScaler.scale(1);
        final estimatedActionsWidth = actions.isEmpty
            ? 0.0
            : (actions.length * 96 * scale).clamp(0.0, contentWidth);
        final expandedStyle = AppType.headline.copyWith(fontSize: 46);
        final collapsedStyle = AppType.headline;
        final expandedTitleWidth = _textWidth(
          context,
          title,
          expandedStyle,
          contentWidth,
        );
        final collapsedTitleWidth = _textWidth(
          context,
          title,
          collapsedStyle,
          contentWidth,
        );
        final stackActions =
            actions.isNotEmpty &&
            (expandedTitleWidth + estimatedActionsWidth > contentWidth ||
                collapsedTitleWidth + estimatedActionsWidth > contentWidth);
        final titleWidth = stackActions
            ? contentWidth
            : (contentWidth - estimatedActionsWidth).clamp(1.0, contentWidth);
        final actionRowHeight = actions.isEmpty
            ? 0.0
            : stackActions
            ? actions.length * 48.0 * scale
            : 48.0;
        final collapsedContentHeight = _textHeight(
          context,
          title,
          collapsedStyle,
          titleWidth,
        );
        final expandedContentHeight = _textHeight(
          context,
          title,
          expandedStyle,
          titleWidth,
        );
        double headerHeight(double titleHeight) =>
            mediaQuery.padding.top +
            (stackActions
                ? titleHeight + 8 + actionRowHeight
                : titleHeight > actionRowHeight
                ? titleHeight
                : actionRowHeight) +
            _headerBottomPadding;
        final minExtent = headerHeight(collapsedContentHeight).clamp(
          _minimumCollapsedHeight + mediaQuery.padding.top,
          double.infinity,
        );
        final maxExtent = headerHeight(expandedContentHeight).clamp(
          _minimumExpandedHeight + mediaQuery.padding.top,
          double.infinity,
        );

        final scrollView = CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _LargeTitleHeaderDelegate(
                title: title,
                actions: actions,
                leading: effectiveLeading,
                background: headerBackground,
                safeTop: mediaQuery.padding.top,
                stackActions: stackActions,
                minHeight: minExtent,
                maxHeight: maxExtent < minExtent ? minExtent : maxExtent,
              ),
            ),
            ...slivers,
            SliverToBoxAdapter(
              child: SizedBox(
                key: const ValueKey('large-title-bottom-clearance'),
                height: bottomClearance,
              ),
            ),
          ],
        );

        return Scaffold(
          backgroundColor: tokens.background,
          body: backgroundDecoration == null
              ? scrollView
              : Stack(
                  children: [
                    Positioned.fill(child: backgroundDecoration!),
                    scrollView,
                  ],
                ),
        );
      },
    );
  }
}

class _LargeTitleHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _LargeTitleHeaderDelegate({
    required this.title,
    required this.actions,
    required this.leading,
    required this.background,
    required this.safeTop,
    required this.stackActions,
    required this.minHeight,
    required this.maxHeight,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? background;
  final double safeTop;
  final bool stackActions;
  final double minHeight;
  final double maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final collapse = range == 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final style = TextStyle.lerp(
      AppType.headline.copyWith(fontSize: 46),
      AppType.headline,
      collapse,
    )!;
    final inlineActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
    final stackedActions = Wrap(
      alignment: WrapAlignment.end,
      children: actions,
    );
    final titleWidget = Text(
      title,
      key: const ValueKey('large-title'),
      style: style,
    );
    final titleAndActions = stackActions
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleWidget, const SizedBox(height: 8), stackedActions],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              if (actions.isNotEmpty) inlineActions,
            ],
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        ?background,
        Padding(
          padding: EdgeInsets.fromLTRB(0, safeTop, 16, 8),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null)
                  SizedBox(width: 56, height: 48, child: leading),
                SizedBox(width: leading == null ? 24 : 0),
                Expanded(child: titleAndActions),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_LargeTitleHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      actions != oldDelegate.actions ||
      leading != oldDelegate.leading ||
      background != oldDelegate.background ||
      safeTop != oldDelegate.safeTop ||
      stackActions != oldDelegate.stackActions ||
      minHeight != oldDelegate.minHeight ||
      maxHeight != oldDelegate.maxHeight;
}
