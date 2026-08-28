import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/features/decks/presentation/deck_library_screen.dart';

import 'support/fake_auth_repository.dart';

Widget _app(FakeAuthRepository fake) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const OpenRecallApp(),
    );

void main() {
  testWidgets('a signed-out launch lands on Login', (tester) async {
    final fake = FakeAuthRepository(signedIn: false);
    addTearDown(fake.dispose);

    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DeckLibraryScreen), findsNothing);
  });

  testWidgets('a signed-in launch lands on the Deck Library', (tester) async {
    final fake = FakeAuthRepository(signedIn: true);
    addTearDown(fake.dispose);

    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.byType(DeckLibraryScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('logging out from the Deck Library returns to Login',
      (tester) async {
    final fake = FakeAuthRepository(signedIn: true);
    addTearDown(fake.dispose);

    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.byType(DeckLibraryScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('signOut()'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
