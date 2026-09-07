import 'package:flutter/material.dart';

/// Centers short pre-session choices and lets taller content scroll within the
/// space supplied by the containing screen.
class PreSessionPickerLayout extends StatelessWidget {
  const PreSessionPickerLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        );

        if (!constraints.hasBoundedHeight) return content;

        return SingleChildScrollView(
          key: const ValueKey('pre-session-picker-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [child],
              ),
            ),
          ),
        );
      },
    );
  }
}
