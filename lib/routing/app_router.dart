import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/decks/presentation/deck_library_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'app_routes.dart';

/// The app's [GoRouter] instance.
///
/// Milestone 1 has no redirect logic — [SplashScreen] performs the single
/// Splash → Login transition itself. Real auth-based routing arrives with
/// Supabase in milestone 3, at which point this provider gains a `redirect`
/// backed by an auth-state listenable.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splashPath,
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
        path: AppRoutes.deckLibraryPath,
        name: AppRoutes.deckLibraryName,
        builder: (context, state) => const DeckLibraryScreen(),
      ),
    ],
  );
});
