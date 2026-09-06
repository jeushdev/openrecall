import 'package:flutter/widgets.dart';

/// The vertical space covered by persistent navigation chrome below a subtree.
///
/// Tab branches use this to keep their final scroll content reachable while the
/// shell continues to paint behind its blurred navigation bar. Standalone
/// routes have no inherited obstruction and use only their system inset.
class NavigationObstruction extends InheritedWidget {
  const NavigationObstruction({
    super.key,
    required this.bottom,
    required super.child,
  });

  final double bottom;

  static double maybeBottomOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NavigationObstruction>()
          ?.bottom ??
      0;

  @override
  bool updateShouldNotify(NavigationObstruction oldWidget) =>
      bottom != oldWidget.bottom;
}
