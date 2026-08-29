import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/routing/placeholders/deck_creator_screen.dart';
import 'package:open_recall/routing/placeholders/decks_tab_screen.dart';
import 'package:open_recall/routing/placeholders/mastery_tab_screen.dart';
import 'package:open_recall/routing/placeholders/settings_tab_screen.dart';
import 'package:open_recall/routing/placeholders/study_session_screen.dart';

import '../support/fake_auth_repository.dart';

Future<void> _pump(WidgetTester tester, {required bool signedIn}) async {
  final fake = FakeAuthRepository(signedIn: signedIn);
  addTearDown(fake.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The [GoRouter] singleton, reachable from any mounted screen. Held onto so a
/// test can keep navigating after the shell itself is torn down by a top-level
/// route.
GoRouter _router(WidgetTester tester) => GoRouter.of(
      tester.element(find.byType(DecksTabScreen, skipOffstage: false).first),
    );

void main() {
  testWidgets('a signed-out launch lands on Login', (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DecksTabScreen), findsNothing);
  });

  testWidgets('a signed-in launch redirects / to the Decks tab with a nav bar',
      (tester) async {
    await _pump(tester, signedIn: true);

    expect(find.byType(DecksTabScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('switching tabs preserves the inactive branch in the IndexedStack',
      (tester) async {
    await _pump(tester, signedIn: true);

    await tester.tap(find.byIcon(Icons.insights_outlined)); // Mastery
    await tester.pumpAndSettle();
    expect(find.byType(MasteryTabScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.style_outlined)); // back to Decks
    await tester.pumpAndSettle();
    expect(find.byType(DecksTabScreen), findsOneWidget);

    // Mastery is off-stage but still mounted — the indexedStack kept its state.
    expect(find.byType(MasteryTabScreen), findsNothing);
    expect(find.byType(MasteryTabScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('pushing /study/:deckId leaves the shell — no bottom bar',
      (tester) async {
    await _pump(tester, signedIn: true);

    _router(tester).go('/study/deck-1');
    await tester.pumpAndSettle();

    expect(find.byType(StudySessionScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Study deck-1 · due'), findsOneWidget);
  });

  testWidgets('the scope query parameter maps to CardScope', (tester) async {
    await _pump(tester, signedIn: true);

    _router(tester).go('/study/deck-1?scope=all');
    await tester.pumpAndSettle();

    expect(find.text('Study deck-1 · all'), findsOneWidget);
  });

  testWidgets('pushing /deck-creator leaves the shell and pops back to its tab',
      (tester) async {
    await _pump(tester, signedIn: true);
    final router = _router(tester);

    // Move to the Settings tab, then launch the creator from there.
    router.go('/settings');
    await tester.pumpAndSettle();
    router.push('/deck-creator');
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SettingsTabScreen), findsOneWidget);
  });
}
