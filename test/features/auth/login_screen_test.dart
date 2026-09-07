import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/features/auth/presentation/signup_screen.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/responsive_test_harness.dart';

Widget _app(FakeAuthRepository fake) => ProviderScope(
  overrides: [
    authRepositoryProvider.overrideWithValue(fake),
    deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
  ],
  child: const OpenRecallApp(),
);

Future<void> _pumpLogin(WidgetTester tester, FakeAuthRepository fake) async {
  await tester.pumpWidget(_app(fake));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

Widget _responsiveAuthHost(
  FakeAuthRepository fake,
  Widget screen,
  double scale,
) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: withTextScale(textScale: scale, child: screen),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('submitting an empty form shows validation errors and does not '
      'call the repository', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await _pumpLogin(tester, fake);

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a valid submission calls signInWithPassword', (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await _pumpLogin(tester, fake);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithPassword(user@example.com)']);
  });

  testWidgets('an auth failure surfaces the mapped message in a SnackBar', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    fake.throwOnNextCall = const AuthApiException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    await _pumpLogin(tester, fake);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump(); // start the async action
    await tester.pump(); // let the listener fire
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the "Create account" link opens the Sign-up screen', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await _pumpLogin(tester, fake);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  final responsiveCases = <({Size size, double scale})>[
    for (final size in responsiveViewports) (size: size, scale: 1),
    (size: const Size(320, 568), scale: 2),
    (size: const Size(360, 640), scale: 2),
    (size: const Size(412, 915), scale: 2),
  ];

  for (final screenCase in const [
    (name: 'login', screen: LoginScreen(), action: 'Log in'),
    (name: 'sign-up', screen: SignupScreen(), action: 'Sign up'),
  ]) {
    for (final testCase in responsiveCases) {
      testWidgets('${screenCase.name} form remains reachable at '
          '${testCase.size.width.toInt()}x${testCase.size.height.toInt()} '
          'and ${testCase.scale}x text', (tester) async {
        final keyboardInset = testCase.scale == 2 ? 260.0 : 0.0;
        configureResponsiveView(
          tester,
          viewport: testCase.size,
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        );
        final fake = FakeAuthRepository();
        addTearDown(fake.dispose);
        await tester.pumpWidget(
          _responsiveAuthHost(fake, screenCase.screen, testCase.scale),
        );
        await tester.pumpAndSettle();

        final email = find.widgetWithText(TextFormField, 'Email');
        final password = find.widgetWithText(TextFormField, 'Password');
        final action = find.widgetWithText(FilledButton, screenCase.action);
        expect(email, findsOneWidget);
        expect(password, findsOneWidget);
        await tester.ensureVisible(action);
        await tester.pump();
        expect(action.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomRight(action).dy,
          lessThanOrEqualTo(testCase.size.height - keyboardInset),
        );
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Enter your email.'), findsOneWidget);
        expect(find.text('Enter your password.'), findsOneWidget);
        expect(fake.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
