import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/notifications/application/notification_providers.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/settings/data/study_appearance_preferences.dart';
import 'package:open_recall/features/settings/data/theme_mode_preference.dart';
import 'package:open_recall/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:open_recall/features/study/application/feynman_timer_providers.dart';
import 'package:open_recall/features/study/data/feynman_timer_preference.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/settings/settings_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_account_repository.dart';
import '../../support/fake_notification_service.dart';

Future<StudyAppearancePreferences> _pump(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const {},
  FakeAccountRepository? account,
  FakeNotificationService? notifications,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final sp = await SharedPreferences.getInstance();
  final appearance = StudyAppearancePreferences(sp);

  // The Settings list is now fully expanded (no section-collapse); give it
  // plenty of room so the lower sections build without every test scrolling.
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyAppearancePreferencesProvider.overrideWithValue(appearance),
        themeModePreferenceProvider.overrideWithValue(ThemeModePreference(sp)),
        feynmanTimerPreferenceProvider
            .overrideWithValue(FeynmanTimerPreference(sp)),
        appVersionProvider.overrideWith((ref) async => '1.2.3+4'),
        accountRepositoryProvider
            .overrideWithValue(account ?? FakeAccountRepository()),
        notificationServiceProvider
            .overrideWithValue(notifications ?? FakeNotificationService()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const SettingsTabScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return appearance;
}

void main() {
  testWidgets('renders both toggles and the section titles', (tester) async {
    await _pump(tester);

    expect(find.text('STUDY APPEARANCE'), findsOneWidget);
    expect(find.text('Card transition'), findsOneWidget);
    expect(find.text('3D flip'), findsOneWidget);
    expect(find.text('Fade & slide'), findsOneWidget);
    expect(find.text('Progress indicator'), findsOneWidget);
    expect(find.text('Hairline'), findsOneWidget);
    expect(find.text('Pill'), findsOneWidget);
    expect(find.text('Card text size'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('XL'), findsOneWidget);
  });

  testWidgets('tapping a segment persists the new value', (tester) async {
    final prefs = await _pump(tester);
    expect(await prefs.cardTransition(), CardTransition.flip3d);

    await tester.tap(find.text('Fade & slide'));
    await tester.pumpAndSettle();

    expect(await prefs.cardTransition(), CardTransition.fade);
  });

  testWidgets('the card text size control toggles and persists', (tester) async {
    final prefs = await _pump(tester);
    expect(await prefs.cardFontSize(), CardFontSize.medium);

    await tester.tap(find.text('XL'));
    await tester.pumpAndSettle();

    expect(await prefs.cardFontSize(), CardFontSize.xlarge);
  });

  testWidgets('the card text size control reflects a stored preset',
      (tester) async {
    await _pump(tester, initialPrefs: {'card_font_size': 'large'});

    final selected = tester.widget<Text>(find.text('L'));
    final medium = tester.widget<Text>(find.text('M'));
    expect(selected.style?.color, isNot(medium.style?.color));
  });

  testWidgets('Feynman row shows the "not yet" copy with no stored preset',
      (tester) async {
    await _pump(tester);
    expect(
      find.textContaining("haven't timed a Feynman session"),
      findsOneWidget,
    );
  });

  testWidgets('Feynman row shows the last-used preset when one is stored',
      (tester) async {
    await _pump(
      tester,
      initialPrefs: {'feynman_timer_seconds_last_used': 90},
    );
    expect(find.textContaining('Last used timer: 90s'), findsOneWidget);
  });

  testWidgets('About shows the app version', (tester) async {
    await _pump(tester);
    expect(find.text('1.2.3+4'), findsOneWidget);
  });

  testWidgets('renders the Appearance section with the theme selector',
      (tester) async {
    await _pump(tester);

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('picking a theme persists it as ThemeMode.name', (tester) async {
    await _pump(tester);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('theme_mode'), isNull);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(sp.getString('theme_mode'), 'dark');
  });

  testWidgets('the theme selector reflects a stored override', (tester) async {
    await _pump(tester, initialPrefs: {'theme_mode': 'light'});

    final selected = tester.widget<Text>(find.text('Light'));
    final other = tester.widget<Text>(find.text('Dark'));
    expect(selected.style?.color, isNot(other.style?.color));
  });

  testWidgets('the reminders toggle reflects and persists the preference',
      (tester) async {
    final notifications = FakeNotificationService();
    await _pump(tester, notifications: notifications);

    // Defaults on for a fresh install.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(notifications.setEnabledCalls, [false]);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getBool('notifications_enabled'), isFalse);
  });

  testWidgets('the reminders toggle reflects a stored "off" preference',
      (tester) async {
    await _pump(tester, initialPrefs: {'notifications_enabled': false});

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('Delete account confirms with the type-DELETE dialog before '
      'calling the repository', (tester) async {
    final account = FakeAccountRepository();
    await _pump(tester, account: account);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountDialog), findsOneWidget);
    // The confirm button is inert until the phrase is typed.
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(account.deleteAccountCalls, 0);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(account.deleteAccountCalls, 1);
  });

  testWidgets('cancelling the delete dialog leaves the account untouched',
      (tester) async {
    final account = FakeAccountRepository();
    await _pump(tester, account: account);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountDialog), findsNothing);
    expect(account.deleteAccountCalls, 0);
  });
}
