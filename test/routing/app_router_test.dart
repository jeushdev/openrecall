import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/domain/card.dart';
import 'package:open_recall/features/decks/presentation/deck_detail_screen.dart';
import 'package:open_recall/features/decks/presentation/decks_tab_screen.dart';
import 'package:open_recall/features/home/presentation/home_tab_screen.dart';
import 'package:open_recall/features/settings/presentation/more_tab_screen.dart';
import 'package:open_recall/features/stats/presentation/history_tab_screen.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/features/study/presentation/study_session_screen.dart';
import 'package:open_recall/routing/ios_tab_bar.dart';
import 'package:open_recall/routing/placeholders/deck_creator_screen.dart';
import 'package:open_recall/ui/settings/settings_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_deck_repository.dart';
import '../support/fake_study_repository.dart';

FlashCard _masteredCard(String id) => FlashCard(
      id: id,
      deckId: 'deck-1',
      front: 'front-$id',
      back: 'back-$id',
      keywords: const [],
      isConcept: false,
      masteryLevel: 4,
      failCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Future<void> _pump(WidgetTester tester, {required bool signedIn}) async {
  // The real Settings screen reads SharedPreferences when /settings is visited.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final fake = FakeAuthRepository(signedIn: signedIn);
  addTearDown(fake.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        deckRepositoryProvider
            .overrideWithValue(FakeDeckRepository(cards: [_masteredCard('a')])),
        studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The [GoRouter] singleton, reachable from any mounted screen. Held onto so a
/// test can keep navigating after the shell itself is torn down by a top-level
/// route.
GoRouter _router(WidgetTester tester) => GoRouter.of(
      tester.element(find.byType(HomeTabScreen, skipOffstage: false).first),
    );

void main() {
  testWidgets('a signed-out launch lands on Login', (tester) async {
    await _pump(tester, signedIn: false);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DecksTabScreen), findsNothing);
  });

  testWidgets('a signed-in launch redirects / to the Home tab with a nav bar',
      (tester) async {
    await _pump(tester, signedIn: true);

    expect(find.byType(HomeTabScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(IosTabBar), findsOneWidget);
  });

  testWidgets('the shell has four branches in order: Home, Decks, History, More',
      (tester) async {
    await _pump(tester, signedIn: true);
    final router = _router(tester);

    for (final (path, matcher) in <(String, Type)>[
      ('/home', HomeTabScreen),
      ('/decks', DecksTabScreen),
      ('/history', HistoryTabScreen),
      ('/more', MoreTabScreen),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.byType(matcher), findsOneWidget, reason: path);
      expect(find.byType(IosTabBar), findsOneWidget, reason: path);
    }
  });

  testWidgets('/settings is reachable but not a shell branch — no bottom bar',
      (tester) async {
    await _pump(tester, signedIn: true);

    _router(tester).go('/settings');
    await tester.pumpAndSettle();

    expect(find.byType(SettingsTabScreen), findsOneWidget);
    expect(find.byType(IosTabBar), findsNothing);
  });

  testWidgets('switching tabs preserves the inactive branch in the IndexedStack',
      (tester) async {
    await _pump(tester, signedIn: true);

    await tester.tap(find.byIcon(Icons.schedule_outlined)); // History
    await tester.pumpAndSettle();
    expect(find.byType(HistoryTabScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined)); // back to Home
    await tester.pumpAndSettle();
    expect(find.byType(HomeTabScreen), findsOneWidget);

    // History is off-stage but still mounted — the indexedStack kept its state.
    expect(find.byType(HistoryTabScreen), findsNothing);
    expect(find.byType(HistoryTabScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('pushing /study/:deckId leaves the shell — no bottom bar',
      (tester) async {
    await _pump(tester, signedIn: true);

    _router(tester).go('/study/deck-1');
    await tester.pumpAndSettle();

    expect(find.byType(StudySessionScreen), findsOneWidget);
    expect(find.byType(IosTabBar), findsNothing);
  });

  testWidgets('a session always runs the whole deck — no scope param needed',
      (tester) async {
    await _pump(tester, signedIn: true);

    // The stub deck's only card is already mastered. The Due view is retired
    // (ui-spec-v2 §1): the router forces CardScope.all, so the card still
    // appears even though the route carries no `scope` query.
    _router(tester).go('/study/deck-1');
    await tester.pumpAndSettle();

    expect(find.byType(StudySessionScreen), findsOneWidget);
    expect(find.byType(IosTabBar), findsNothing);
    expect(find.text('front-a'), findsOneWidget);
  });

  testWidgets('pushing /deck/:deckId opens deck detail outside the shell',
      (tester) async {
    await _pump(tester, signedIn: true);

    _router(tester).go('/deck/deck-1');
    await tester.pumpAndSettle();

    expect(find.byType(DeckDetailScreen), findsOneWidget);
    expect(find.byType(IosTabBar), findsNothing);
  });

  testWidgets('pushing /deck-creator leaves the shell and pops back to its tab',
      (tester) async {
    await _pump(tester, signedIn: true);
    final router = _router(tester);

    // Move to the History tab, then launch the creator from there.
    router.go('/history');
    await tester.pumpAndSettle();
    router.push('/deck-creator');
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsOneWidget);
    expect(find.byType(IosTabBar), findsNothing);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(DeckCreatorScreen), findsNothing);
    expect(find.byType(IosTabBar), findsOneWidget);
    expect(find.byType(HistoryTabScreen), findsOneWidget);
  });
}
