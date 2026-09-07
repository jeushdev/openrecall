import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/stats/presentation/history_tab_screen.dart';
import 'package:open_recall/routing/ios_tab_bar.dart';
import 'package:open_recall/theme/app_tokens.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_deck_repository.dart';
import '../support/responsive_test_harness.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  required Size size,
  required double textScale,
}) async {
  configureResponsiveView(
    tester,
    viewport: size,
    viewPadding: const EdgeInsets.only(bottom: 24),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [AppTokens.light]),
      home: withTextScale(
        textScale: textScale,
        child: Scaffold(
          bottomNavigationBar: IosTabBar(currentIndex: 0, onSelectTab: (_) {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpSignedIn(WidgetTester tester) async {
  final fake = FakeAuthRepository(signedIn: true);
  addTearDown(fake.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Color _iconColor(WidgetTester tester, String key) {
  final icon = tester.widget<Icon>(
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Icon)),
  );
  return icon.color!;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('labels fit their tab targets across the responsive matrix', (
    tester,
  ) async {
    for (final size in responsiveViewports) {
      for (final scale in responsiveTextScales) {
        await _pumpBar(tester, size: size, textScale: scale);

        expect(
          tester.takeException(),
          isNull,
          reason: '$size at text scale $scale',
        );
        for (final (key, label) in const [
          ('nav-home', 'Home'),
          ('nav-decks', 'Decks'),
          ('nav-history', 'History'),
          ('nav-more', 'More'),
        ]) {
          final target = tester.getRect(find.byKey(ValueKey(key)));
          final text = tester.getRect(find.text(label));
          expect(
            text.left >= target.left &&
                text.top >= target.top &&
                text.right <= target.right &&
                text.bottom <= target.bottom,
            isTrue,
            reason:
                '$label at $size and text scale $scale: target=$target text=$text',
          );
        }
      }
    }
  });

  testWidgets(
    'bar height follows text requirements instead of viewport height',
    (tester) async {
      await _pumpBar(tester, size: const Size(320, 568), textScale: 1);
      final normalHeight = tester.getSize(find.byType(IosTabBar)).height;

      await _pumpBar(tester, size: const Size(320, 960), textScale: 1);
      expect(tester.getSize(find.byType(IosTabBar)).height, normalHeight);

      await _pumpBar(tester, size: const Size(320, 568), textScale: 2);
      expect(
        tester.getSize(find.byType(IosTabBar)).height,
        greaterThan(normalHeight),
      );
    },
  );

  testWidgets('renders the four tab targets', (tester) async {
    await _pumpSignedIn(tester);

    expect(find.byType(IosTabBar), findsOneWidget);
    for (final key in const [
      'nav-home',
      'nav-decks',
      'nav-history',
      'nav-more',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('conveys selection by icon colour only — active vs inactive', (
    tester,
  ) async {
    await _pumpSignedIn(tester);

    // Launch lands on the Home tab (branch 0).
    expect(_iconColor(tester, 'nav-home'), AppTokens.light.tint);
    expect(_iconColor(tester, 'nav-decks'), AppTokens.light.textSecondary);
    expect(_iconColor(tester, 'nav-history'), AppTokens.light.textSecondary);
    expect(_iconColor(tester, 'nav-more'), AppTokens.light.textSecondary);
  });

  testWidgets('tapping a tab switches the shell branch', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-history')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryTabScreen), findsOneWidget);
    expect(_iconColor(tester, 'nav-history'), AppTokens.light.tint);
    expect(_iconColor(tester, 'nav-home'), AppTokens.light.textSecondary);
  });
}
