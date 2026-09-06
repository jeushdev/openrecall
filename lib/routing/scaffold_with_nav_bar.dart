import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/offline_banner.dart';
import '../ui/common/navigation_obstruction.dart';
import 'ios_tab_bar.dart';

/// The shell chrome wrapped around the four tab branches
/// (`/home`, `/decks`, `/history`, `/more`).
///
/// The bottom nav bar is "conditionally rendered" purely by tree structure: it
/// lives here, inside [StatefulShellRoute], and is simply never part of the
/// widget tree for the top-level routes (`/study/:deckId`, `/deck-creator`) —
/// not hidden via opacity/visibility (ui-spec-v1 §4).
///
/// The bar itself is [IosTabBar] (ui-spec-v5 §5.1). The scaffold runs
/// `extendBody: true` so each branch renders full-height behind the full-width
/// tab bar and its [BackdropFilter] has live content to blur.
///
/// ## Branch transition (milestone UX4)
///
/// All four branch navigators (supplied by the router's
/// `navigatorContainerBuilder` as [children]) stay mounted in a [Stack] of
/// [Offstage] widgets so every tab keeps its state. When
/// [StatefulNavigationShell.currentIndex] changes, the incoming branch slides
/// in and the outgoing branch slides out along the x-axis: moving to a
/// higher-index tab slides the view left, a lower-index tab slides it right.
///
/// The active branch is **not** wrapped in an [AnimatedSwitcher]: the branch
/// navigators carry internal [GlobalKey]s, and an `AnimatedSwitcher` keeps the
/// outgoing and incoming subtrees mounted under *different* slots at once,
/// which throws duplicate-`GlobalKey` errors. The [Stack] here keeps each
/// branch in a single stable slot for its whole lifetime.
class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;

  /// The persistent branch [Navigator]s, one per tab, in branch order. Passed
  /// straight through from the router's `navigatorContainerBuilder`.
  final List<Widget> children;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with SingleTickerProviderStateMixin {
  static const _still = AlwaysStoppedAnimation(Offset.zero);
  static const _duration = Duration(milliseconds: 240);

  /// Branch order is fixed in `app_router.dart`: 0 Home, 1 Decks, 2 History,
  /// 3 More. No index here is special-cased — `/settings` left the shell
  /// (ui-spec-v4-navigation §2).
  late final AnimationController _controller;

  /// The branch currently settling into place.
  late int _currentIndex;

  /// The branch sliding out, kept on-stage until the slide finishes; `null`
  /// when nothing is transitioning.
  int? _outgoingIndex;

  Animation<Offset> _incomingSlide = _still;
  Animation<Offset> _outgoingSlide = _still;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _outgoingIndex != null) {
          setState(() => _outgoingIndex = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.navigationShell.currentIndex;
    if (next == _currentIndex) return;

    // Higher index → the view travels left: the incoming branch enters from the
    // right (+x → 0) while the outgoing branch exits to the left (0 → -x). A
    // lower index mirrors both directions.
    final goingLeft = next > _currentIndex;
    _incomingSlide = _controller.drive(
      Tween<Offset>(
        begin: Offset(goingLeft ? 1 : -1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _outgoingSlide = _controller.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: Offset(goingLeft ? -1 : 1, 0),
      ).chain(CurveTween(curve: Curves.easeInCubic)),
    );

    _outgoingIndex = _currentIndex;
    _currentIndex = next;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again returns it to its initial location.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Animation<Offset> _slideFor(int i) {
    if (i == _currentIndex) return _incomingSlide;
    if (i == _outgoingIndex) return _outgoingSlide;
    return _still;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final tabBarContentHeight = IosTabBar.contentHeightFor(
      context,
      mediaQuery.size.width,
    );
    final navigationObstruction =
        tabBarContentHeight + mediaQuery.viewPadding.bottom;
    final tabs = Stack(
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != _currentIndex && i != _outgoingIndex,
            child: SlideTransition(
              position: _slideFor(i),
              child: widget.children[i],
            ),
          ),
      ],
    );

    return Scaffold(
      extendBody: true,
      // The offline strip (design spec §E.1) sits above every tab. The top
      // inset is consumed once here so the per-tab `SafeArea`s below become
      // top no-ops and the strip is never tucked under the status bar.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: NavigationObstruction(
                bottom: navigationObstruction,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: tabs,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: IosTabBar(
        currentIndex: widget.navigationShell.currentIndex,
        onSelectTab: _goBranch,
        contentHeight: tabBarContentHeight,
      ),
    );
  }
}
