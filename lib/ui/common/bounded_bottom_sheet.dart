import 'package:flutter/material.dart';

/// A bottom-sheet body that stays compact when its content fits and scrolls
/// when content, text scaling, safe-area padding, or the keyboard needs more
/// vertical space than the modal route can provide.
///
/// The modal route owns the sheet's outer height and top/side safe areas. This
/// widget owns bottom safe-area padding, keyboard clearance, and scrolling so
/// callers do not apply the keyboard inset a second time.
class BoundedBottomSheetBody extends StatelessWidget {
  const BoundedBottomSheetBody({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          key: const ValueKey('bounded-bottom-sheet-scroll'),
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: child,
        ),
      ),
    );
  }
}
