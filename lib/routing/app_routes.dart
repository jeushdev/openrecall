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

  // --- Shell tabs (ui-spec-v4-navigation §2). Four branches of a
  //     StatefulShellRoute, in order: Home, Decks, History, More. The bottom
  //     nav bar is part of the shell scaffold and never mounts outside it.

  /// Home (ui-spec-v4-navigation §3). The shell's default branch.
  static const String homePath = '/home';
  static const String homeName = 'home';

  static const String deckLibraryPath = '/decks';
  static const String deckLibraryName = 'decks';

  /// History (ui-spec-v4-navigation §4) — replaces the retired Mastery tab.
  static const String historyPath = '/history';
  static const String historyName = 'history';

  /// More (ui-spec-v4-navigation §5) — replaces the retired Profile tab; the
  /// entry point into the pushed `/settings` route.
  static const String morePath = '/more';
  static const String moreName = 'more';

  /// Settings & account management (spec §9, ui-spec-v1 §6.5). No longer a
  /// shell branch (ui-spec-v4-navigation §2) — a normal pushed route reached
  /// from a row inside `MoreTabScreen`.
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

  /// Deck detail (ui-spec-v2 §6.3), at `/deck/:deckId`. The mode picker + Import
  /// + View cards + edit/delete deck screen a deck tile now opens instead of
  /// going straight to a study session. Top-level, so the bottom bar is absent.
  static const String deckDetailPath = '/deck/:deckId';
  static const String deckDetailName = 'deck-detail';

  /// Import cards (ui-spec-v2 §6.4), at `/deck/:deckId/import` — the unified
  /// manual-add + bulk-paste screen (U14). Reached from the + menu, the deck
  /// detail screen, and the study-session "add cards" dead-ends.
  static const String importCardsPath = '/deck/:deckId/import';
  static const String importCardsName = 'import-cards';

  /// Card list (ui-spec-v2 §6.5), at `/deck/:deckId/cards` — view / edit / delete
  /// a deck's cards. Reached from the deck detail screen and the Import screen.
  static const String cardListPath = '/deck/:deckId/cards';
  static const String cardListName = 'card-list';

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
