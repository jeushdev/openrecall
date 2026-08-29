import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_geometry.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/theme/app_tokens.dart';

void main() {
  group('AppTokens resolution', () {
    testWidgets('resolves from context via AppTheme.light without throwing',
        (tester) async {
      AppTokens? resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context).extension<AppTokens>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved, isNotNull);
      expect(resolved, same(AppTokens.light));
    });
  });

  group('AppTokens.light palette hexes (spec §3.1)', () {
    const t = AppTokens.light;

    test('surface + text tokens map to the exact spec hexes', () {
      expect(t.background, const Color(0xFFFFFFFF));
      expect(t.cardFill, const Color(0xFFFFFFFF));
      expect(t.mutedFill, const Color(0xFFF7F7F5));
      expect(t.borderHairline, const Color(0xFFEDEDED));
      expect(t.textPrimary, const Color(0xFF1A1A1A));
      expect(t.textSecondary, const Color(0xFF8A8A8A));
      expect(t.textTertiary, const Color(0xFFB0B0B0));
    });
  });

  group('AppTokens.light accents (spec §3.2)', () {
    const t = AppTokens.light;

    test('contains exactly the 8 named accent_color keys', () {
      expect(
        t.accents.keys.toSet(),
        <String>{
          'slate',
          'red',
          'amber',
          'green',
          'teal',
          'blue',
          'violet',
          'pink',
        },
      );
    });

    test('each key maps to its exact fill/text hex pair', () {
      expect(t.accents['slate'],
          const AccentPair(Color(0xFFCBD5E1), Color(0xFF64748B)));
      expect(t.accents['red'],
          const AccentPair(Color(0xFFD06C60), Color(0xFFB0453A)));
      expect(t.accents['amber'],
          const AccentPair(Color(0xFFD6C08B), Color(0xFF8A7534)));
      expect(t.accents['green'],
          const AccentPair(Color(0xFFAFC3A8), Color(0xFF6E8A65)));
      expect(t.accents['teal'],
          const AccentPair(Color(0xFF8FC4BE), Color(0xFF3F7A73)));
      expect(t.accents['blue'],
          const AccentPair(Color(0xFF9DBDD2), Color(0xFF4E7B95)));
      expect(t.accents['violet'],
          const AccentPair(Color(0xFFB8AED9), Color(0xFF6D5FA8)));
      expect(t.accents['pink'],
          const AccentPair(Color(0xFFE3AEBE), Color(0xFFB15C74)));
    });

    test('accent() falls back to slate for an unknown key', () {
      expect(AppTokens.light.accent('not-a-real-key'),
          AppTokens.light.accents['slate']);
      expect(AppTokens.light.accent('blue'), AppTokens.light.accents['blue']);
    });
  });

  group('AppTokens copyWith / lerp', () {
    const t = AppTokens.light;

    test('copyWith overrides one field and leaves the rest', () {
      final next = t.copyWith(background: const Color(0xFF000000));
      expect(next.background, const Color(0xFF000000));
      expect(next.textPrimary, t.textPrimary);
      expect(next.accents, t.accents);
    });

    test('lerp with a non-AppTokens other returns this', () {
      expect(t.lerp(null, 0.5), same(t));
    });

    test('lerp at t=0 keeps this, at t=1 reaches other', () {
      final other = t.copyWith(background: const Color(0xFF000000));
      expect(t.lerp(other, 0.0).background, t.background);
      expect(t.lerp(other, 1.0).background, other.background);
      expect(t.lerp(other, 0.5).accents['red'], t.accents['red']);
    });
  });

  group('Geometry constants (spec §3.3)', () {
    test('radii and border widths match the spec', () {
      expect(AppRadii.card, 28.0);
      expect(AppRadii.gridTile, 16.0);
      expect(AppBorders.hairline, 0.5);
      expect(AppRadii.cardRadius, BorderRadius.circular(28.0));
      expect(AppRadii.gridTileRadius, BorderRadius.circular(16.0));
    });
  });
}
