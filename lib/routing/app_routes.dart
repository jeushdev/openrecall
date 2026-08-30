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

  /// Study session (ui-spec-v1 §6.2), at `/study/:deckId`. Takes no query
  /// parameters — the Due view is retired (ui-spec-v2 §1), so the session
  /// always runs `CardScope.all`.
  static const String studySessionPath = '/study/:deckId';
  static const String studySessionName = 'study-session';

  /// Deck Creator / card-manager (ui-spec-v1 §4). Pushed by the shell's centre
  /// Create action so back-navigation returns to whichever tab launched it.
  static const String deckCreatorPath = '/deck-creator';
  static const String deckCreatorName = 'deck-creator';

  /// Course Creator (ui-spec-v2 §6.2), at `/course-creator`. Name + accent
  /// picker; a top-level route so the bottom bar is absent while creating it.
  static const String courseCreatorPath = '/course-creator';
  static const String courseCreatorName = 'course-creator';

  /// Add Card — a rapid single-card entry screen for one deck, at
  /// `/deck/:deckId/add-card` (optional `name` query parameter for the title).
  /// Reached straight after creating a deck and from the study-session
  /// dead-ends. Outside the shell, like the study session.
  static const String addCardPath = '/deck/:deckId/add-card';
  static const String addCardName = 'add-card';

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
