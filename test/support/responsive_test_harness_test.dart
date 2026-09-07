import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'responsive_test_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('configures logical geometry at a non-unit pixel ratio', (
    tester,
  ) async {
    configureResponsiveView(
      tester,
      viewport: const Size(320, 568),
      devicePixelRatio: 2,
      viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
      viewInsets: const EdgeInsets.only(bottom: 240),
    );

    late MediaQueryData media;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            media = MediaQuery.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(media.size, const Size(320, 568));
    expect(media.padding.top, 24);
    expect(media.padding.bottom, 0);
    expect(media.viewPadding.bottom, 16);
    expect(media.viewInsets.bottom, 240);
    expect(
      visibleLogicalRect(tester, keyboardInset: 240),
      const Rect.fromLTWH(0, 0, 320, 328),
    );
  });

  testWidgets('preserves view media data while applying text scale', (
    tester,
  ) async {
    configureResponsiveView(
      tester,
      viewport: const Size(393, 873),
      viewPadding: const EdgeInsets.only(top: 31, bottom: 19),
    );

    late MediaQueryData media;
    await tester.pumpWidget(
      MaterialApp(
        home: withTextScale(
          textScale: 1.5,
          child: Builder(
            builder: (context) {
              media = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(media.size, const Size(393, 873));
    expect(media.padding, const EdgeInsets.only(top: 31, bottom: 19));
    expect(media.textScaler.scale(20), 30);
  });

  testWidgets('later configurations replace earlier view state', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(320, 568));
    configureResponsiveView(
      tester,
      viewport: const Size(480, 960),
      viewPadding: EdgeInsets.zero,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(
      tester.view.physicalSize / tester.view.devicePixelRatio,
      const Size(480, 960),
    );
  });

  testWidgets('configures system text scaling for a real app root', (
    tester,
  ) async {
    configureResponsiveView(tester, viewport: const Size(360, 640));
    configurePlatformTextScale(tester, 2);
    late TextScaler scaler;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scaler = MediaQuery.textScalerOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scaler.scale(10), 20);
  });
}
