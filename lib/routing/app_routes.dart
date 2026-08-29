/// Route paths and names for the app router.
///
/// Kept as plain constants so screens can navigate without importing the
/// router itself. See [appRouterProvider] in `app_router.dart`.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String splashPath = '/';
  static const String splashName = 'splash';

  static const String loginPath = '/login';
  static const String loginName = 'login';

  static const String signupPath = '/signup';
  static const String signupName = 'signup';

  static const String forgotPasswordPath = '/forgot-password';
  static const String forgotPasswordName = 'forgot-password';

  static const String deckLibraryPath = '/decks';
  static const String deckLibraryName = 'decks';

  /// Settings & account management (spec §9). Top-level, signed-in only —
  /// [authRedirect] already permits any unlisted path for a signed-in user.
  static const String settingsPath = '/settings';
  static const String settingsName = 'settings';

  /// Deck Overview (spec §4). Nested under [deckLibraryPath] as `/decks/:deckId`
  /// so the back button returns to the library. Takes a `deckId` path parameter
  /// and, optionally, the deck name as `extra` for the app-bar title.
  static const String deckOverviewPath = ':deckId';
  static const String deckOverviewName = 'deck-overview';

  /// Deck Creator / card-manager, at `/decks/:deckId/edit`. Reached from
  /// "+Create deck" (a fresh empty deck) and from the Overview's "Add cards".
  /// Same `deckId` path parameter and `extra` deck name as the Overview.
  static const String deckCreatorPath = 'edit';
  static const String deckCreatorName = 'deck-creator';

  /// Study session (spec §5), at `/decks/:deckId/study`. Nested under the
  /// Overview so exiting returns there. Takes a `StudySessionArgs` as `extra`.
  static const String studySessionPath = 'study';
  static const String studySessionName = 'study-session';

  /// Routes a signed-out user is allowed to sit on.
  static const Set<String> unauthenticatedPaths = {
    loginPath,
    signupPath,
    forgotPasswordPath,
  };
}
