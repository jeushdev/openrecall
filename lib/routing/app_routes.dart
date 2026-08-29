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

  // --- Shell tabs (ui-spec-v1 §4). Four branches of a
  //     StatefulShellRoute.indexedStack; the bottom nav bar is part of the
  //     shell scaffold and never mounts outside it.

  static const String deckLibraryPath = '/decks';
  static const String deckLibraryName = 'decks';

  static const String masteryPath = '/mastery';
  static const String masteryName = 'mastery';

  static const String profilePath = '/profile';
  static const String profileName = 'profile';

  /// Settings & account management (spec §9, ui-spec-v1 §6.5).
  static const String settingsPath = '/settings';
  static const String settingsName = 'settings';

  // --- Top-level routes, outside the shell (ui-spec-v1 §4). No bottom bar.

  /// Study session (ui-spec-v1 §6.2), at `/study/:deckId`. Accepts an optional
  /// `scope=due|all` query parameter mapping to `CardScope`; defaults to `due`.
  static const String studySessionPath = '/study/:deckId';
  static const String studySessionName = 'study-session';

  /// Deck Creator / card-manager (ui-spec-v1 §4). Pushed by the shell's centre
  /// Create action so back-navigation returns to whichever tab launched it.
  static const String deckCreatorPath = '/deck-creator';
  static const String deckCreatorName = 'deck-creator';

  // --- Legacy — screens not yet rewired into the revamp shell (U4/U5). The
  //     `DeckLibraryScreen` / `DeckOverviewScreen` widgets still reference
  //     `deckOverviewName` and compile, but no route is registered for it, so
  //     a `pushNamed` would throw at runtime. They are unreachable until U4.
  static const String deckOverviewName = 'deck-overview';

  /// Routes a signed-out user is allowed to sit on.
  static const Set<String> unauthenticatedPaths = {
    loginPath,
    signupPath,
    forgotPasswordPath,
  };
}
