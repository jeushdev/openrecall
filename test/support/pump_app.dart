import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/core/local_db/local_db_providers.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/decks/data/local_deck_store.dart';
import 'package:open_recall/features/study/application/session_controller.dart';

import 'fake_auth_repository.dart';
import 'fake_deck_repository.dart';
import 'fake_study_repository.dart';

/// Pumps the full [OpenRecallApp] with the auth, deck, and study repositories
/// replaced by in-memory fakes, so a test never needs `Supabase.initialize()`.
///
/// Pass `signedIn: true` for tests that start past the login gate.
Future<
  ({
    FakeAuthRepository auth,
    FakeDeckRepository decks,
    FakeStudyRepository study,
  })
>
pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  FakeDeckRepository? decks,
  FakeStudyRepository? study,
  bool online = true,
  LocalDeckStore? localDecks,
  bool settle = true,
}) async {
  final auth = FakeAuthRepository(signedIn: signedIn);
  final deckRepo = decks ?? FakeDeckRepository();
  final studyRepo = study ?? FakeStudyRepository();
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        deckRepositoryProvider.overrideWithValue(deckRepo),
        studyRepositoryProvider.overrideWithValue(studyRepo),
        onlineStatusProvider.overrideWith((ref) => Stream.value(online)),
        if (localDecks != null)
          localDeckStoreProvider.overrideWithValue(localDecks),
      ],
      child: const OpenRecallApp(),
    ),
  );
  // Some tests assert what is on screen *before* the deck-list revalidation
  // resolves (milestone E1) — `pumpAndSettle` would wait it out.
  if (settle) await tester.pumpAndSettle();

  return (auth: auth, decks: deckRepo, study: studyRepo);
}
