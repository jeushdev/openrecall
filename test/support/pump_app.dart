import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';

import 'fake_auth_repository.dart';
import 'fake_deck_repository.dart';

/// Pumps the full [OpenRecallApp] with the auth and deck repositories replaced
/// by in-memory fakes, so a test never needs `Supabase.initialize()`.
///
/// Pass `signedIn: true` for tests that start past the login gate.
Future<({FakeAuthRepository auth, FakeDeckRepository decks})> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  FakeDeckRepository? decks,
}) async {
  final auth = FakeAuthRepository(signedIn: signedIn);
  final deckRepo = decks ?? FakeDeckRepository();
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        deckRepositoryProvider.overrideWithValue(deckRepo),
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();

  return (auth: auth, decks: deckRepo);
}
