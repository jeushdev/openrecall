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

  /// Deck Creator / card-manager. Nested under [deckLibraryPath] so the back
  /// button returns to the library. Takes a `deckId` path parameter and,
  /// optionally, the deck name as `extra` for the app-bar title.
  static const String deckCreatorPath = ':deckId';
  static const String deckCreatorName = 'deck-creator';

  /// Routes a signed-out user is allowed to sit on.
  static const Set<String> unauthenticatedPaths = {
    loginPath,
    signupPath,
    forgotPasswordPath,
  };
}
