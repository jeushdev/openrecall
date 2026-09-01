import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/ui/web_app_frame.dart';
import 'package:open_recall/theme/app_theme.dart';

const _childKey = Key('framed-child');

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: WebAppFrame(
          enabled: true,
          child: SizedBox.expand(
            child: ColoredBox(color: Color(0xFF00FF00), key: _childKey),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('above the breakpoint the child is constrained to the content width',
      (tester) async {
    await _pumpAt(tester, const Size(1200, 900));
    expect(tester.getSize(find.byKey(_childKey)).width, kWebFrameContentWidth);
  });

  testWidgets('below the breakpoint the child is passed through full-width',
      (tester) async {
    await _pumpAt(tester, const Size(375, 800));
    expect(tester.getSize(find.byKey(_childKey)).width, 375);
  });

  testWidgets('disabled is always a pass-through even on a wide viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebAppFrame(
            child: SizedBox.expand(
              child: ColoredBox(color: Color(0xFF00FF00), key: _childKey),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_childKey)).width, 1200);
  });
}
