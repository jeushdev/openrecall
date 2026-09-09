import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/features/settings/data/study_appearance_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        studyAppearancePreferencesProvider.overrideWithValue(
          StudyAppearancePreferences(sp),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('build() surfaces the persisted selection', () async {
    final c = await container({
      'card_transition': 'fade',
      'progress_indicator': 'pill',
    });

    final value = await c.read(studyAppearanceProvider.future);
    expect(value.cardTransition, CardTransition.fade);
    expect(value.progressIndicator, ProgressIndicatorStyle.pill);
  });

  test('setCardTransition updates state and persists', () async {
    final c = await container({});
    await c.read(studyAppearanceProvider.future);

    await c
        .read(studyAppearanceProvider.notifier)
        .setCardTransition(CardTransition.fade);

    expect(
      c.read(studyAppearanceProvider).asData?.value.cardTransition,
      CardTransition.fade,
    );

    // A fresh controller (new build) reads the same value back from storage.
    c.invalidate(studyAppearanceProvider);
    final reloaded = await c.read(studyAppearanceProvider.future);
    expect(reloaded.cardTransition, CardTransition.fade);
  });

  test('setProgressIndicator updates state and persists', () async {
    final c = await container({});
    await c.read(studyAppearanceProvider.future);

    await c
        .read(studyAppearanceProvider.notifier)
        .setProgressIndicator(ProgressIndicatorStyle.pill);

    c.invalidate(studyAppearanceProvider);
    final reloaded = await c.read(studyAppearanceProvider.future);
    expect(reloaded.progressIndicator, ProgressIndicatorStyle.pill);
  });

  test(
    'card font size defaults to medium and round-trips through the provider',
    () async {
      final c = await container({});
      expect(
        (await c.read(studyAppearanceProvider.future)).cardFontSize,
        CardFontSize.medium,
      );

      await c
          .read(studyAppearanceProvider.notifier)
          .setCardFontSize(CardFontSize.large);

      expect(
        c.read(studyAppearanceProvider).asData?.value.cardFontSize,
        CardFontSize.large,
      );

      c.invalidate(studyAppearanceProvider);
      final reloaded = await c.read(studyAppearanceProvider.future);
      expect(reloaded.cardFontSize, CardFontSize.large);
    },
  );
}
