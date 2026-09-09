import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/routing/app_routes.dart';
import 'package:open_recall/routing/auth_redirect.dart';

void main() {
  group('authRedirect (signed out)', () {
    test('sends the splash and any protected route to Login', () {
      expect(
        authRedirect(signedIn: false, location: AppRoutes.splashPath),
        AppRoutes.loginPath,
      );
      expect(
        authRedirect(signedIn: false, location: AppRoutes.deckLibraryPath),
        AppRoutes.loginPath,
      );
    });

    test('leaves the login, signup, and forgot-password routes alone', () {
      expect(
        authRedirect(signedIn: false, location: AppRoutes.loginPath),
        isNull,
      );
      expect(
        authRedirect(signedIn: false, location: AppRoutes.signupPath),
        isNull,
      );
      expect(
        authRedirect(signedIn: false, location: AppRoutes.forgotPasswordPath),
        isNull,
      );
    });
  });

  group('authRedirect (signed in)', () {
    test('sends the splash and auth routes to Home', () {
      expect(
        authRedirect(signedIn: true, location: AppRoutes.splashPath),
        AppRoutes.homePath,
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.loginPath),
        AppRoutes.homePath,
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.signupPath),
        AppRoutes.homePath,
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.forgotPasswordPath),
        AppRoutes.homePath,
      );
    });

    test('leaves a protected route alone', () {
      expect(
        authRedirect(signedIn: true, location: AppRoutes.homePath),
        isNull,
      );
      expect(
        authRedirect(signedIn: true, location: AppRoutes.deckLibraryPath),
        isNull,
      );
    });
  });
}
