import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/features/settings/application/settings_providers.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/theme/app_tokens.dart';

void main() {
  group('AppTokens.dark palette hexes (spec-v5 §2)', () {
    const t = AppTokens.dark;

    test('surface + text tokens map to the exact spec hexes', () {
      expect(t.background, const Color(0xFF121212));
      expect(t.cardFill, const Color(0xFF1E1E1E));
      expect(t.mutedFill, const Color(0xFF262624));
      expect(t.borderHairline, const Color(0xFF333333));
      expect(t.textPrimary, const Color(0xFFECECEC));
      expect(t.textSecondary, const Color(0xFF9A9A9A));
      expect(t.textTertiary, const Color(0xFF6E6E6E));
    });

    test('carries exactly the 8 named accent keys', () {
      expect(
        t.accents.keys.toSet(),
        <String>{'slate', 'red', 'amber', 'green', 'teal', 'blue', 'violet',
            'pink'},
      );
    });

    test('the fixed "Mastered" red is the nudged dark fill', () {
      expect(t.accent('red').fill, const Color(0xFFDA7C6F));
    });
  });

  group('AppTheme.dark', () {
    testWidgets('resolves AppTokens.dark from context without throwing',
        (tester) async {
      AppTokens? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).extension<AppTokens>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(AppTokens.dark));
      expect(Theme.of(tester.element(find.byType(SizedBox))).brightness,
          Brightness.dark);
    });

    testWidgets(
        'ThemeMode.system + dark platform brightness picks up AppTokens.dark',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue,
      );

      late AppTokens resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).extension<AppTokens>()!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, same(AppTokens.dark));
      expect(resolved.background, const Color(0xFF121212));
    });
  });

  testWidgets('themeModeProvider configures MaterialApp.themeMode', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final mode =
                ref.watch(themeModeProvider).value ?? ThemeMode.system;
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: Builder(
                builder: (c) {
                  captured = c;
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(Theme.of(captured).brightness, Brightness.dark);
    expect(Theme.of(captured).extension<AppTokens>(), same(AppTokens.dark));
  });
}
