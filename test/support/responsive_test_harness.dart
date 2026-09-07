import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const responsiveViewports = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(393, 873),
  Size(412, 915),
  Size(480, 960),
];

const responsiveTextScales = <double>[1, 1.3, 1.5, 2];

void configureResponsiveView(
  WidgetTester tester, {
  required Size viewport,
  double devicePixelRatio = 1,
  EdgeInsets viewPadding = const EdgeInsets.only(top: 24, bottom: 24),
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = viewport * devicePixelRatio;
  tester.view.viewPadding = _fakePadding(viewPadding * devicePixelRatio);
  tester.view.viewInsets = _fakePadding(viewInsets * devicePixelRatio);
  tester.view.padding = _fakePadding(
    EdgeInsets.fromLTRB(
          (viewPadding.left - viewInsets.left).clamp(0, double.infinity),
          (viewPadding.top - viewInsets.top).clamp(0, double.infinity),
          (viewPadding.right - viewInsets.right).clamp(0, double.infinity),
          (viewPadding.bottom - viewInsets.bottom).clamp(0, double.infinity),
        ) *
        devicePixelRatio,
  );
  addTearDown(tester.view.reset);
}

void configurePlatformTextScale(WidgetTester tester, double textScale) {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

FakeViewPadding _fakePadding(EdgeInsets padding) => FakeViewPadding(
  left: padding.left,
  top: padding.top,
  right: padding.right,
  bottom: padding.bottom,
);

Widget withTextScale({required double textScale, required Widget child}) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

Future<void>? _fontLoad;

Future<void> loadAppFonts() => _fontLoad ??= Future.wait([
  _loadFont('Figtree', const ['assets/fonts/Figtree.ttf']),
  _loadFont('Inter', const [
    'assets/fonts/Inter.ttf',
    'assets/fonts/Inter-Italic.ttf',
  ]),
]);

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

void expectContained(
  WidgetTester tester, {
  required Finder inner,
  required Finder outer,
  double tolerance = 0.01,
}) {
  final innerRect = tester.getRect(inner);
  final outerRect = tester.getRect(outer);
  expect(innerRect.left, greaterThanOrEqualTo(outerRect.left - tolerance));
  expect(innerRect.top, greaterThanOrEqualTo(outerRect.top - tolerance));
  expect(innerRect.right, lessThanOrEqualTo(outerRect.right + tolerance));
  expect(innerRect.bottom, lessThanOrEqualTo(outerRect.bottom + tolerance));
}

void expectTextIsComplete(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  expect(text.overflow, isNot(TextOverflow.ellipsis));
  expect(text.maxLines, anyOf(isNull, greaterThan(1)));
}

Rect visibleLogicalRect(WidgetTester tester, {double keyboardInset = 0}) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Rect.fromLTRB(0, 0, size.width, size.height - keyboardInset);
}
