import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_recall/app.dart';
import 'package:open_recall/features/auth/application/auth_providers.dart';
import 'package:open_recall/features/decks/application/deck_providers.dart';
import 'package:open_recall/features/home/presentation/home_tab_screen.dart';
import 'package:open_recall/features/study/application/session_controller.dart';
import 'package:open_recall/ui/settings/settings_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_deck_repository.dart';
import '../../support/fake_study_repository.dart';

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final fake = FakeAuthRepository(signedIn: true);
  addTearDown(fake.dispose);

  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        deckRepositoryProvider.overrideWithValue(FakeDeckRepository()),
        studyRepositoryProvider.overrideWithValue(FakeStudyRepository()),
      ],
      child: const OpenRecallApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('re-entering the Settings screen resets every section to collapsed',
      (tester) async {
    await _pump(tester);

    final router = GoRouter.of(tester.element(find.byType(HomeTabScreen)));

    router.push('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsTabScreen), findsOneWidget);

    await tester.tap(find.text('Study appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Card transition'), findsOneWidget);

    // Leave the screen and come back.
    router.pop();
    await tester.pumpAndSettle();
    router.push('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Card transition'), findsNothing);
  });
}
