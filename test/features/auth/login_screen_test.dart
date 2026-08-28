import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/auth/presentation/login_screen.dart';
import 'package:open_recall/features/auth/presentation/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';

Widget _app(FakeAuthRepository fake) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const OpenRecallApp(),
    );

Future<void> _pumpLogin(WidgetTester tester, FakeAuthRepository fake) async {
  await tester.pumpWidget(_app(fake));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

void main() {
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
        find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithPassword(user@example.com)']);
  });

  testWidgets('an auth failure surfaces the mapped message in a SnackBar',
      (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    fake.throwOnNextCall = const AuthApiException('Invalid login credentials',
        statusCode: '400', code: 'invalid_credentials');
    await _pumpLogin(tester, fake);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump(); // start the async action
    await tester.pump(); // let the listener fire
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the "Create account" link opens the Sign-up screen',
      (tester) async {
    final fake = FakeAuthRepository();
    addTearDown(fake.dispose);
    await _pumpLogin(tester, fake);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });
}
