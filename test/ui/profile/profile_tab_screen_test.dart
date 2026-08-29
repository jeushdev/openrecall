import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/stats/application/stats_providers.dart';
import 'package:open_recall/core/sync/sync_providers.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/profile/profile_tab_screen.dart';

import '../../support/fake_auth_repository.dart';

Future<FakeAuthRepository> _pump(
  WidgetTester tester, {
  String? email = 'jeush.beta@example.com',
  int streak = 5,
  int mastery = 42,
  bool pendingWrites = false,
}) async {
  final auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userIdentityProvider.overrideWithValue((email: email)),
        currentStreakProvider.overrideWith((ref) async => streak),
        overallMasteryProvider.overrideWith((ref) async => mastery),
        pendingSyncProvider.overrideWith((ref) async => pendingWrites),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ProfileTabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('shows the email and initials derived from it', (tester) async {
    await _pump(tester);

    expect(find.text('jeush.beta@example.com'), findsOneWidget);
    expect(find.text('JE'), findsOneWidget);
  });

  testWidgets('renders the streak and mastery stat blocks', (tester) async {
    await _pump(tester, streak: 5, mastery: 42);

    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Overall mastery'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('sign out opens a plain confirm dialog when nothing is pending',
      (tester) async {
    await _pump(tester, pendingWrites: false);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out?'), findsOneWidget);
    expect(find.textContaining("sign back in"), findsOneWidget);
    expect(find.textContaining('synced'), findsNothing);
  });

  testWidgets('the dialog warns about unsynced writes when some are pending',
      (tester) async {
    await _pump(tester, pendingWrites: true);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.textContaining("hasn't synced"), findsOneWidget);
  });

  testWidgets('confirming the dialog signs out through the auth repository',
      (tester) async {
    final auth = await _pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signOut()'));
  });

  testWidgets('cancelling the dialog does not sign out', (tester) async {
    final auth = await _pump(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
  });
}
