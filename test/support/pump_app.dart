import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
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
    })> pumpApp(
  WidgetTester tester, {
  bool signedIn = false,
  FakeDeckRepository? decks,
  FakeStudyRepository? study,
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
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();

  return (auth: auth, decks: deckRepo, study: studyRepo);
}
