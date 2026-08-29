import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/decks/presentation/decks_tab_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/study/domain/study_session.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';
import 'go_router_refresh_stream.dart';
import 'placeholders/deck_creator_screen.dart';
import 'placeholders/mastery_tab_screen.dart';
import 'placeholders/profile_tab_screen.dart';
import 'placeholders/settings_tab_screen.dart';
import 'placeholders/study_session_screen.dart';
import 'scaffold_with_nav_bar.dart';

/// The app's [GoRouter] instance (ui-spec-v1 §4).
///
/// A [StatefulShellRoute.indexedStack] preserves each tab branch's state across
/// switches; [ScaffoldWithNavBar] supplies the shell chrome. Everything else —
/// the study session and the deck creator — is a top-level route outside the
/// shell, so the bottom nav bar is naturally absent there.
///
/// Auth is the other routing concern: [authRedirect] gates every navigation
/// against the current session and [GoRouterRefreshStream] re-runs it whenever
/// the session appears or clears. [SplashScreen] is a passive frame — the
/// redirect resolves `/` to Login or `/decks` on the first build.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(auth.authStateChanges());
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splashPath,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      signedIn: auth.isSignedIn,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signupPath,
        name: AppRoutes.signupName,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPasswordPath,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.deckLibraryPath,
                name: AppRoutes.deckLibraryName,
                builder: (context, state) => const DecksTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.masteryPath,
                name: AppRoutes.masteryName,
                builder: (context, state) => const MasteryTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profilePath,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfileTabScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settingsPath,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsTabScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.studySessionPath,
        name: AppRoutes.studySessionName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => StudySessionScreen(
          deckId: state.pathParameters['deckId']!,
          // `scope` maps directly to CardScope; anything but `all` (including
          // absent or malformed) resolves to `due` per §4.
          scope: cardScopeFromDb(state.uri.queryParameters['scope'] ?? 'due'),
        ),
      ),
      GoRoute(
        path: AppRoutes.deckCreatorPath,
        name: AppRoutes.deckCreatorName,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DeckCreatorScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
