import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/decks/presentation/deck_creator_screen.dart';
import '../features/decks/presentation/deck_library_screen.dart';
import '../features/decks/presentation/deck_overview_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';
import 'go_router_refresh_stream.dart';

/// The app's [GoRouter] instance.
///
/// Auth is the only routing concern: [authRedirect] gates every navigation
/// against the current session, and [GoRouterRefreshStream] re-runs it whenever
/// the session appears or clears. [SplashScreen] is now a passive frame — the
/// redirect resolves `/` to Login or the Deck Library on the first build.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(auth.authStateChanges());

  final router = GoRouter(
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
      GoRoute(
        path: AppRoutes.deckLibraryPath,
        name: AppRoutes.deckLibraryName,
        builder: (context, state) => const DeckLibraryScreen(),
        routes: [
          GoRoute(
            path: AppRoutes.deckOverviewPath,
            name: AppRoutes.deckOverviewName,
            builder: (context, state) => DeckOverviewScreen(
              deckId: state.pathParameters['deckId']!,
              deckName: state.extra as String?,
            ),
            routes: [
              GoRoute(
                path: AppRoutes.deckCreatorPath,
                name: AppRoutes.deckCreatorName,
                builder: (context, state) => DeckCreatorScreen(
                  deckId: state.pathParameters['deckId']!,
                  deckName: state.extra as String?,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
