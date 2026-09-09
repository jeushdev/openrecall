import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/profile/application/profile_providers.dart';
import 'package:open_recall/features/profile/presentation/profile_edit_sheet.dart';
import 'package:open_recall/theme/app_theme.dart';

import '../../support/fake_profile_repository.dart';

Future<FakeProfileRepository> _open(
  WidgetTester tester, {
  String? username,
  double textScale = 1,
}) async {
  final repo = FakeProfileRepository(
    profile: (id: 'u1', email: 'a@b.com', username: username),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    ProfileEditSheet.show(context, currentName: username),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('opens above shell navigation instead of inside the tab', (
    tester,
  ) async {
    var navigationTaps = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(
              profile: (id: 'u1', email: 'a@b.com', username: 'Ada'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (nestedContext) => Center(
                  child: FilledButton(
                    onPressed: () => ProfileEditSheet.show(
                      nestedContext,
                      currentName: 'Ada',
                    ),
                    child: const Text('open nested'),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SizedBox(
              height: 80,
              child: Material(
                child: InkWell(
                  onTap: () => navigationTaps++,
                  child: const Center(child: Text('Shell navigation')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open nested'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shell navigation'), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(ProfileEditSheet), findsOneWidget);
    expect(navigationTaps, 0);
  });

  testWidgets(
    'validation and Save stay reachable with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);

      final repo = await _open(tester, username: null, textScale: 2);
      await tester.enterText(find.byType(TextField), 'x' * 31);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Keep it under 30 characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Grace');
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.scrollUntilVisible(
        save,
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('bounded-bottom-sheet-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(268));
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.updateUsernameCalls, ['Grace']);
    },
  );

  testWidgets('prefills the current username', (tester) async {
    await _open(tester, username: 'Ada');
    expect(find.widgetWithText(TextField, 'Ada'), findsOneWidget);
  });

  testWidgets('Save is disabled until the value changes', (tester) async {
    await _open(tester, username: 'Ada');
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('typing a new name and tapping Save calls the controller', (
    tester,
  ) async {
    final repo = await _open(tester, username: null);
    await tester.enterText(find.byType(TextField), '  Grace Hopper ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.updateUsernameCalls, ['Grace Hopper']);
    expect(find.byType(TextField), findsNothing); // sheet popped
  });

  testWidgets('clearing a set name saves null', (tester) async {
    final repo = await _open(tester, username: 'Ada');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.updateUsernameCalls, [null]);
  });

  testWidgets('over 30 chars disables Save and shows the hint', (tester) async {
    await _open(tester, username: null);
    await tester.enterText(find.byType(TextField), 'x' * 31);
    await tester.pump();

    expect(find.text('Keep it under 30 characters.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('a save failure keeps the sheet open with a snackbar', (
    tester,
  ) async {
    final repo = await _open(tester, username: null);
    repo.throwOnNextCall = Exception('offline');
    await tester.enterText(find.byType(TextField), 'Grace');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save your name, try again."), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // still open
  });
}
