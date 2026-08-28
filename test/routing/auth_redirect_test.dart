import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/routing/auth_redirect.dart';

void main() {
  group('authRedirect (signed out)', () {
    test('sends the splash and any protected route to Login', () {
      expect(authRedirect(signedIn: false, location: AppRoutes.splashPath),
          AppRoutes.loginPath);
      expect(authRedirect(signedIn: false, location: AppRoutes.deckLibraryPath),
          AppRoutes.loginPath);
    });

    test('leaves the login, signup, and forgot-password routes alone', () {
      expect(authRedirect(signedIn: false, location: AppRoutes.loginPath),
          isNull);
      expect(authRedirect(signedIn: false, location: AppRoutes.signupPath),
          isNull);
      expect(
          authRedirect(
              signedIn: false, location: AppRoutes.forgotPasswordPath),
          isNull);
    });
  });

  group('authRedirect (signed in)', () {
    test('sends the splash and auth routes to the Deck Library', () {
      expect(authRedirect(signedIn: true, location: AppRoutes.splashPath),
          AppRoutes.deckLibraryPath);
      expect(authRedirect(signedIn: true, location: AppRoutes.loginPath),
          AppRoutes.deckLibraryPath);
      expect(authRedirect(signedIn: true, location: AppRoutes.signupPath),
          AppRoutes.deckLibraryPath);
      expect(
          authRedirect(signedIn: true, location: AppRoutes.forgotPasswordPath),
          AppRoutes.deckLibraryPath);
    });

    test('leaves the Deck Library alone', () {
      expect(authRedirect(signedIn: true, location: AppRoutes.deckLibraryPath),
          isNull);
    });
  });
}
