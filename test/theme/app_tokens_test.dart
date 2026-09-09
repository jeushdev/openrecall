import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_geometry.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/theme/app_tokens.dart';

void main() {
  group('AppTokens resolution', () {
    testWidgets('resolves from context via AppTheme.light without throwing', (
      tester,
    ) async {
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

    test('surface + text tokens map to the exact ui-spec-v5 hexes', () {
      expect(t.background, const Color(0xFFF2F2F7));
      expect(t.cardFill, const Color(0xFFFFFFFF));
      expect(t.mutedFill, const Color(0xFFEFEFF4));
      expect(t.borderHairline, const Color(0xFFC6C6C8));
      expect(t.textPrimary, const Color(0xFF1C1C1E));
      expect(t.textSecondary, const Color(0xFF8E8E93));
      expect(t.textTertiary, const Color(0xFFC7C7CC));
      expect(t.tint, const Color(0xFF007AFF));
    });
  });

  group('AppTokens.dark palette hexes (ui-spec-v5 §3)', () {
    const t = AppTokens.dark;

    test('surface + text tokens map to the exact ui-spec-v5 hexes', () {
      expect(t.background, const Color(0xFF000000));
      expect(t.cardFill, const Color(0xFF1C1C1E));
      expect(t.mutedFill, const Color(0xFF2C2C2E));
      expect(t.borderHairline, const Color(0xFF38383A));
      expect(t.textPrimary, const Color(0xFFFFFFFF));
      expect(t.textSecondary, const Color(0xFF98989F));
      expect(t.textTertiary, const Color(0xFF48484A));
      expect(t.tint, const Color(0xFF0A84FF));
    });
  });

  group('AppTokens.light accents (spec §3.2)', () {
    const t = AppTokens.light;

    test('contains exactly the 8 named accent_color keys', () {
      expect(t.accents.keys.toSet(), <String>{
        'slate',
        'red',
        'amber',
        'green',
        'teal',
        'blue',
        'violet',
        'pink',
      });
    });

    test('each key maps to its exact fill/text hex pair', () {
      expect(
        t.accents['slate'],
        const AccentPair(Color(0xFFC7C7CC), Color(0xFF8E8E93)),
      );
      expect(
        t.accents['red'],
        const AccentPair(Color(0xFFFF6961), Color(0xFFFF3B30)),
      );
      expect(
        t.accents['amber'],
        const AccentPair(Color(0xFFFFB340), Color(0xFFFF9500)),
      );
      expect(
        t.accents['green'],
        const AccentPair(Color(0xFF63DA83), Color(0xFF34C759)),
      );
      expect(
        t.accents['teal'],
        const AccentPair(Color(0xFF5AC8E0), Color(0xFF30B0C7)),
      );
      expect(
        t.accents['blue'],
        const AccentPair(Color(0xFF4DA2FF), Color(0xFF007AFF)),
      );
      expect(
        t.accents['violet'],
        const AccentPair(Color(0xFF8886E0), Color(0xFF5856D6)),
      );
      expect(
        t.accents['pink'],
        const AccentPair(Color(0xFFFF6482), Color(0xFFFF2D55)),
      );
    });

    test('accent() falls back to slate for an unknown key', () {
      expect(
        AppTokens.light.accent('not-a-real-key'),
        AppTokens.light.accents['slate'],
      );
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

  group('Geometry constants (ui-spec-v5 §3)', () {
    test('radii and border widths match ui-spec-v5', () {
      expect(AppRadii.card, 20.0);
      expect(AppRadii.gridTile, 16.0);
      expect(AppRadii.section, 12.0);
      expect(AppRadii.control, 12.0);
      expect(AppRadii.button, 14.0);
      expect(AppBorders.hairline, 1.0);
      expect(AppRadii.cardRadius, BorderRadius.circular(20.0));
      expect(AppRadii.gridTileRadius, BorderRadius.circular(16.0));
    });

    test('AppShadows: soft card shadow in light, none in dark', () {
      expect(AppShadows.card(Brightness.light), isNotEmpty);
      expect(AppShadows.card(Brightness.dark), isEmpty);
      expect(AppShadows.raised(Brightness.light), isNotEmpty);
    });
  });
}
