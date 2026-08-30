import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/data/study_appearance_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StudyAppearancePreferences> prefs(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    return StudyAppearancePreferences(await SharedPreferences.getInstance());
  }

  test('defaults to 3D flip and hairline when nothing is stored', () async {
    final p = await prefs({});
    expect(await p.cardTransition(), CardTransition.flip3d);
    expect(await p.progressIndicator(), ProgressIndicatorStyle.hairline);
  });

  test('round-trips the card transition', () async {
    final p = await prefs({});
    await p.setCardTransition(CardTransition.fade);
    expect(await p.cardTransition(), CardTransition.fade);
  });

  test('defaults the card font size to medium when nothing is stored', () async {
    final p = await prefs({});
    expect(await p.cardFontSize(), CardFontSize.medium);
  });

  test('round-trips the card font size', () async {
    final p = await prefs({});
    await p.setCardFontSize(CardFontSize.xlarge);
    expect(await p.cardFontSize(), CardFontSize.xlarge);
  });

  test('reads back a previously persisted card font size', () async {
    final p = await prefs({'card_font_size': 'large'});
    expect(await p.cardFontSize(), CardFontSize.large);
  });

  test('falls back to medium on an unrecognized stored font size', () async {
    final p = await prefs({'card_font_size': 'gigantic'});
    expect(await p.cardFontSize(), CardFontSize.medium);
  });

  test('round-trips the progress indicator', () async {
    final p = await prefs({});
    await p.setProgressIndicator(ProgressIndicatorStyle.pill);
    expect(await p.progressIndicator(), ProgressIndicatorStyle.pill);
  });

  test('reads back a previously persisted value', () async {
    final p = await prefs({
      'card_transition': 'fade',
      'progress_indicator': 'pill',
    });
    expect(await p.cardTransition(), CardTransition.fade);
    expect(await p.progressIndicator(), ProgressIndicatorStyle.pill);
  });

  test('falls back to the default on an unrecognized stored string', () async {
    final p = await prefs({'card_transition': 'legacy-value'});
    expect(await p.cardTransition(), CardTransition.flip3d);
  });
}
