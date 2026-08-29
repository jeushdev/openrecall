import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/settings/data/study_appearance_preferences.dart';
import 'package:open_recall/features/study/application/feynman_timer_providers.dart';
import 'package:open_recall/features/study/data/feynman_timer_preference.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/settings/settings_tab_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StudyAppearancePreferences> _pump(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final sp = await SharedPreferences.getInstance();
  final appearance = StudyAppearancePreferences(sp);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyAppearancePreferencesProvider.overrideWithValue(appearance),
        feynmanTimerPreferenceProvider
            .overrideWithValue(FeynmanTimerPreference(sp)),
        appVersionProvider.overrideWith((ref) async => '1.2.3+4'),
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

    expect(find.text('Study appearance'), findsOneWidget);
    expect(find.text('Card transition'), findsOneWidget);
    expect(find.text('3D flip'), findsOneWidget);
    expect(find.text('Fade & slide'), findsOneWidget);
    expect(find.text('Progress indicator'), findsOneWidget);
    expect(find.text('Hairline'), findsOneWidget);
    expect(find.text('Pill'), findsOneWidget);
  });

  testWidgets('tapping a segment persists the new value', (tester) async {
    final prefs = await _pump(tester);
    expect(await prefs.cardTransition(), CardTransition.flip3d);

    await tester.tap(find.text('Fade & slide'));
    await tester.pumpAndSettle();

    expect(await prefs.cardTransition(), CardTransition.fade);
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
}
