import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/routing/glass_bottom_nav_bar.dart';
import 'package:open_recall/routing/placeholders/deck_creator_screen.dart';
import 'package:open_recall/routing/placeholders/mastery_tab_screen.dart';
import 'package:open_recall/theme/app_tokens.dart';

import '../support/fake_auth_repository.dart';

Future<void> _pumpSignedIn(WidgetTester tester) async {
  final fake = FakeAuthRepository(signedIn: true);
  addTearDown(fake.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Color _iconColor(WidgetTester tester, String key) {
  final icon = tester.widget<Icon>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Icon),
    ),
  );
  return icon.color!;
}

void main() {
  testWidgets('renders the four tab targets plus the Create button',
      (tester) async {
    await _pumpSignedIn(tester);

    expect(find.byType(GlassBottomNavBar), findsOneWidget);
    for (final key in const [
      'nav-decks',
      'nav-mastery',
      'nav-create',
      'nav-profile',
      'nav-settings',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('conveys selection by icon colour only — active vs inactive',
      (tester) async {
    await _pumpSignedIn(tester);

    // Launch lands on the Decks tab (branch 0).
    expect(_iconColor(tester, 'nav-decks'), AppTokens.light.textPrimary);
    expect(_iconColor(tester, 'nav-mastery'), AppTokens.light.textTertiary);
    expect(_iconColor(tester, 'nav-profile'), AppTokens.light.textTertiary);
    expect(_iconColor(tester, 'nav-settings'), AppTokens.light.textTertiary);
  });

  testWidgets('tapping a tab switches the shell branch', (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-mastery')));
    await tester.pumpAndSettle();

    expect(find.byType(MasteryTabScreen), findsOneWidget);
    expect(_iconColor(tester, 'nav-mastery'), AppTokens.light.textPrimary);
    expect(_iconColor(tester, 'nav-decks'), AppTokens.light.textTertiary);
  });

  testWidgets('tapping Create pushes /deck-creator and leaves the shell',
      (tester) async {
    await _pumpSignedIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-create')));
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsOneWidget);
    expect(find.byType(GlassBottomNavBar), findsNothing);
  });
}
