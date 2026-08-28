import 'app_routes.dart';

/// The app's single auth-gating rule, factored out of the [GoRouter] config so
/// it can be unit-tested. Returns the path to redirect to, or `null` to stay.
///
/// - Signed out: only the login / signup / forgot-password routes are allowed;
///   everything else (including the splash) goes to Login.
/// - Signed in: the splash and the auth routes bounce to the Deck Library;
///   everything else is allowed.
String? authRedirect({required bool signedIn, required String location}) {
  final atUnauthenticated = AppRoutes.unauthenticatedPaths.contains(location);

  if (!signedIn) {
    return atUnauthenticated ? null : AppRoutes.loginPath;
  }

  if (atUnauthenticated || location == AppRoutes.splashPath) {
    return AppRoutes.deckLibraryPath;
  }
  return null;
}
