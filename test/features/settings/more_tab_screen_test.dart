import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/core/connectivity/connectivity_service.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/settings/presentation/more_tab_screen.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/presentation/profile_edit_sheet.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/ui/profile/sign_out_dialog.dart';
import 'package:open_recall/ui/settings/settings_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';
import '../../support/responsive_test_harness.dart';

Future<GoRouter> _pumpMore(
  WidgetTester tester, {
  String? email,
  String? username,
  Size viewport = const Size(1000, 2200),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // The four groups run past the 800×600 default viewport; give the list room
  // so the lower rows (About, Version) build without every test scrolling.
  configureResponsiveView(
    tester,
    viewport: viewport,
    viewPadding: EdgeInsets.zero,
  );
  configurePlatformTextScale(tester, textScale);
  final auth = FakeAuthRepository(signedIn: true);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
        studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
        onlineStatusProvider.overrideWith((ref) => Stream.value(true)),
        appVersionProvider.overrideWith((ref) async => '1.2.3+4'),
        userIdentityProvider.overrideWithValue((email: email)),
        profileProvider.overrideWith(
          (ref) async => username == null
              ? null
              : (id: 'u1', email: email ?? 'a@b.com', username: username),
        ),
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();

  final ctx = tester.element(find.byType(Navigator).first);
  final router = GoRouter.of(ctx);
  router.go('/more');
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('renders the profile block and the four grouped sections', (
    tester,
  ) async {
    await _pumpMore(tester);

    expect(find.byType(MoreTabScreen), findsOneWidget);
    // No Supabase in the widget-test graph, so `userIdentityProvider` yields a
    // null email and the identity block renders its signed-out fallback.
    expect(find.text('Not signed in'), findsOneWidget);
    // IosSection headers render uppercased.
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('DATA'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('1.2.3+4'), findsOneWidget);
  });

  testWidgets('the identity row opens the edit-name sheet, not Settings', (
    tester,
  ) async {
    await _pumpMore(
      tester,
      email: 'jeush.b@example.com',
      username: 'Ada Lovelace',
    );

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileEditSheet), findsOneWidget);
  });

  testWidgets('the identity row shows the username when one is set', (
    tester,
  ) async {
    await _pumpMore(
      tester,
      email: 'jeush.b@example.com',
      username: 'Ada Lovelace',
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets(
    'the identity row shows the email-derived name when no username',
    (tester) async {
      await _pumpMore(tester, email: 'jeush.b@example.com');
      expect(find.text('Jeush'), findsOneWidget);
    },
  );

  testWidgets('offline sync shows an "Up to date" status with nothing queued', (
    tester,
  ) async {
    await _pumpMore(tester);
    expect(find.text('Offline sync'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
  });

  testWidgets('a preferences row pushes the Settings screen', (tester) async {
    await _pumpMore(tester);

    await tester.tap(find.text('Study preferences'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsTabScreen), findsOneWidget);
  });

  testWidgets('Help & feedback opens the shared feedback dialog', (
    tester,
  ) async {
    await _pumpMore(tester);

    await tester.tap(find.text('Help & feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Feedback link coming soon'), findsOneWidget);
  });

  testWidgets('tapping Sign out asks for confirmation first', (tester) async {
    await _pumpMore(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(SignOutDialog), findsOneWidget);
  });

  final responsiveCases = <({Size size, double scale})>[
    for (final size in responsiveViewports) (size: size, scale: 1),
    (size: const Size(320, 568), scale: 2),
    (size: const Size(360, 640), scale: 2),
    (size: const Size(412, 915), scale: 2),
  ];

  for (final testCase in responsiveCases) {
    testWidgets('lower More actions remain reachable at '
        '${testCase.size.width.toInt()}x${testCase.size.height.toInt()} '
        'and ${testCase.scale}x text', (tester) async {
      await _pumpMore(
        tester,
        email: 'a.very.long.account.address@example.com',
        username: 'A Very Long Responsive Account Name',
        viewport: testCase.size,
        textScale: testCase.scale,
      );

      expect(find.byType(MoreTabScreen), findsOneWidget);
      final feedback = find.text('Help & feedback');
      await tester.scrollUntilVisible(
        feedback,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(feedback.hitTestable(), findsOneWidget);
      expectTextIsComplete(tester, feedback);
      final version = find.text('1.2.3+4');
      await tester.scrollUntilVisible(
        version,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(version.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
