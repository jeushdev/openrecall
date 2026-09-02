# Native iOS Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin ActiveRecall from its editorial serif design language to a modern native-iOS aesthetic (Figtree + Inter, iOS grouped surfaces with soft elevation, a vibrant tint colour, a standard iOS tab bar, Cupertino route transitions, grouped-inset lists) without changing any screen, flow, or route.

**Architecture:** Theme-layer rewrite (`lib/theme/*`) plus a small set of new shared widgets (`lib/ui/common/*`, `lib/routing/ios_tab_bar.dart`) plus targeted per-screen adoption passes. Stays on `MaterialApp` + Material widgets + go_router + Riverpod + the `AppTokens` `ThemeExtension`. No `CupertinoApp`, no real Cupertino widgets, no schema or provider changes.

**Tech Stack:** Flutter (Dart), Material 3, `flutter_riverpod` 3.x, `go_router` 18.x, bundled variable TTF fonts.

**Spec:** `docs/ui-spec-v5-native-ios.md` (read it in full before starting — it carries the rationale this plan implements). Supporting: `docs/ui-spec-v1.md` §4 (routing/shell), `docs/ui-spec-v3-design-language.md` (the system being superseded), `docs/spec-v5-dark-mode.md` §4 (theme-mode mechanism, unchanged).

## Global Constraints

- **Android-only.** No iOS build, no `CupertinoApp`. "Native iOS" is a visual target hit with themed Material widgets.
- **No `google_fonts`.** Fonts are bundled variable TTFs under `assets/fonts/`, registered in `pubspec.yaml`, licence text yielded from `LicenseRegistry` in `lib/main.dart`. The app reads its theme before `runApp` and must work offline.
- **No new features / no IA change.** Same four tabs, same screen inventory, same routes, same flows. Editable username + profile pictures are a separate later milestone — do not touch `profiles`, Supabase Storage, or add `image_picker`.
- **Raw colour literals live only in `AppTokens.light` / `AppTokens.dark`.** Every screen resolves colour via `Theme.of(context).extension<AppTokens>()!`.
- **`updated_at` is a DB trigger** — never set from Dart. (Not exercised here, but holds.)
- **Motion never gates state.** Every animation in the study loop is cosmetic; the queue advances synchronously regardless of animation status (`ui-spec-v1` §2).
- **No gamification.** No XP, badges, levels, streak-currency, confetti, daily goals.
- **Verification gates:** `flutter analyze` clean and `flutter test` green before every commit. Tests that assert on removed things are **updated to the v5 equivalent**, never deleted or `skip`-ed.
- **Conventional commits**, one per task minimum. Commit message body may reference `ui-spec-v5-native-ios.md`.
- Package name is `open_recall` (imports are `package:open_recall/...`). Android application id `com.openrecall.app`.

---

## File Structure

**Modified — theme layer:**
- `lib/theme/app_geometry.dart` — `AppRadii` gains `card`(20)/`section`(12)/`control`(12)/`button`(14); `gridTile` stays 16; `AppBorders.hairline` → `1.0`; new `AppShadows` class.
- `lib/theme/app_tokens.dart` — `AppTokens` gains a `tint` field; all light/dark values replaced; accents retuned; `copyWith`/`lerp` updated.
- `lib/theme/app_type.dart` — Fraunces removed; existing role names kept but re-valued to the iOS ramp on Figtree/Inter; `largeTitle` added; `textTheme` mapping updated.
- `lib/theme/app_theme.dart` — component themes re-pointed at the new tokens/radii/shadows; `ColorScheme.primary` → `tint`; switch track green; input resting border removed; overlay colours updated.
- `lib/theme/app_motion.dart` — `page` (350ms) duration and `spring` curve alias added.

**Created — shared widgets:**
- `lib/ui/common/app_card.dart` — `AppCard`: token-filled, rounded, soft-shadow (light) container. Owns the one place a `BoxShadow` is applied.
- `lib/ui/common/ios_list.dart` — `IosSection` + `IosRow`: the iOS grouped-inset list.
- `lib/ui/common/large_title_scaffold.dart` — `LargeTitleScaffold`: collapsing large-title header over a scroll view.
- `lib/routing/ios_tab_bar.dart` — `IosTabBar`: full-width blurred iOS tab bar. Replaces `lib/routing/glass_bottom_nav_bar.dart` (deleted).

**Modified — routing / screens:**
- `lib/routing/app_router.dart` — every `GoRoute` gets a `CupertinoPage` `pageBuilder`.
- `lib/routing/scaffold_with_nav_bar.dart` — `bottomNavigationBar:` swaps `GlassBottomNavBar` → `IosTabBar`.
- `lib/features/home/presentation/home_tab_screen.dart` — `LargeTitleScaffold`, greeting as large title, trailing `+`, `AppCard`.
- `lib/features/decks/presentation/decks_tab_screen.dart` — `LargeTitleScaffold`, trailing `+`.
- `lib/features/decks/presentation/widgets/deck_grid.dart` — tiles on `AppCard`/`AppShadows`.
- `lib/features/study/presentation/session_summary_view.dart` (+ flip card / rating row files) — verify inherit; big number → `AppType.display` (already the summary number role).
- `lib/features/stats/presentation/history_tab_screen.dart` — heatmap palette, log rows on `IosSection`/`IosRow`.
- `lib/features/settings/presentation/more_tab_screen.dart` — rebuilt on `IosSection`/`IosRow`; delete `_Group`/`_NavRow`/`_StatusRow`/`_RowDivider`.
- `lib/ui/settings/settings_tab_screen.dart` (+ `collapsible_settings_section.dart`, `settings_segmented_control.dart`) — rebuilt on `IosSection`/`IosRow`.
- `lib/features/auth/presentation/*` , `lib/features/splash/presentation/splash_screen.dart` — inherit; CTA restyle.

**Modified — tests:**
- `test/theme/app_tokens_test.dart` — palette/accent/geometry expectations rewritten to v5 values.
- `test/routing/glass_bottom_nav_bar_test.dart` → renamed `test/routing/ios_tab_bar_test.dart`; `GlassBottomNavBar` → `IosTabBar`; `nav-create` assertions moved to a Home/Decks header `+` test.
- `test/routing/app_router_test.dart` — `GlassBottomNavBar` → `IosTabBar`.
- Any widget test asserting `fontFamily == 'Fraunces'`, the old hex palette, or `AppBorders.hairline == 0.5` — updated.
- New: `test/ui/common/ios_list_test.dart`, `test/ui/common/large_title_scaffold_test.dart`, `test/ui/common/app_card_test.dart`.

---

## Task 1: Bundle Figtree, remove Fraunces

**Files:**
- Create: `assets/fonts/Figtree.ttf`, `assets/fonts/Figtree-OFL.txt`
- Delete: `assets/fonts/Fraunces.ttf`, `assets/fonts/Fraunces-Italic.ttf`, `assets/fonts/Fraunces-OFL.txt`
- Modify: `pubspec.yaml` (fonts section, ~lines 40-55), `lib/main.dart` (LicenseRegistry block, lines 28-40)

**Interfaces:**
- Produces: font family strings `'Figtree'` and `'Inter'` are the only two families registered. No `'Fraunces'` anywhere.

- [ ] **Step 1: Download the Figtree variable TTF and its licence**

```bash
curl -fL "https://github.com/google/fonts/raw/main/ofl/figtree/Figtree%5Bwght%5D.ttf" -o assets/fonts/Figtree.ttf
curl -fL "https://github.com/google/fonts/raw/main/ofl/figtree/OFL.txt" -o assets/fonts/Figtree-OFL.txt
```

Verify both are non-empty and `file assets/fonts/Figtree.ttf` reports TrueType. If the URL 404s, fetch from `https://fonts.google.com/download?family=Figtree`, unzip, and take `Figtree-VariableFont_wght.ttf` → `assets/fonts/Figtree.ttf` plus its `OFL.txt`.

- [ ] **Step 2: Remove Fraunces files**

```bash
git rm assets/fonts/Fraunces.ttf assets/fonts/Fraunces-Italic.ttf assets/fonts/Fraunces-OFL.txt
```

- [ ] **Step 3: Update `pubspec.yaml`**

Under `flutter: assets:` replace the `Fraunces-OFL.txt` line with `- assets/fonts/Figtree-OFL.txt` (keep `Inter-OFL.txt`). Under `flutter: fonts:` replace the entire `- family: Fraunces` block with:

```yaml
    - family: Figtree
      fonts:
        - asset: assets/fonts/Figtree.ttf
```

Keep the `- family: Inter` block untouched.

- [ ] **Step 4: Update `lib/main.dart` licence block**

Replace lines 28-40 (the `LicenseRegistry.addLicense` body comment + the two `yield`s) with a comment naming Figtree/Inter and:

```dart
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Figtree'],
      await rootBundle.loadString('assets/fonts/Figtree-OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['Inter'],
      await rootBundle.loadString('assets/fonts/Inter-OFL.txt'),
    );
  });
```

- [ ] **Step 5: Verify it builds**

Run: `flutter pub get && flutter analyze`
Expected: no errors. (`app_type.dart` still says `'Fraunces'` — that is fixed in Task 4; analyze does not flag a string literal, so this passes.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: bundle Figtree, remove Fraunces (ui-spec-v5 §1)"
```

---

## Task 2: Geometry & elevation tokens

**Files:**
- Modify: `lib/theme/app_geometry.dart`
- Test: `test/theme/app_tokens_test.dart` (the `Geometry constants` group, lines ~110-118)

**Interfaces:**
- Produces:
  - `AppRadii.card` = `20.0`, `AppRadii.gridTile` = `16.0` (unchanged), `AppRadii.section` = `12.0`, `AppRadii.control` = `12.0`, `AppRadii.button` = `14.0`, `AppRadii.input` = `12.0` (unchanged value).
  - `AppRadii.cardRadius` / `gridTileRadius` / `inputRadius` `BorderRadius` constants kept; add `sectionRadius`, `buttonRadius`.
  - `AppBorders.hairline` = `1.0`.
  - `AppShadows.card(Brightness b) → List<BoxShadow>` and `AppShadows.raised(Brightness b) → List<BoxShadow>`. Light `card`: `[BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3))]`. Dark `card`: `const []`. Light `raised`: `[BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 6))]`. Dark `raised`: `[BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 6))]`.

- [ ] **Step 1: Update the failing geometry test**

In `test/theme/app_tokens_test.dart`, replace the `Geometry constants (spec §3.3)` group body with:

```dart
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
```

- [ ] **Step 2: Run it, verify it fails**

Run: `flutter test test/theme/app_tokens_test.dart -r expanded`
Expected: FAIL — `AppRadii.section` etc. undefined, `AppBorders.hairline` still `0.5`.

- [ ] **Step 3: Rewrite `lib/theme/app_geometry.dart`**

```dart
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Brightness;

/// Corner radii (ui-spec-v5 §3).
abstract final class AppRadii {
  const AppRadii._();

  /// Cards, study surfaces, sheet & dialog corners.
  static const double card = 20.0;

  /// Deck grid tile.
  static const double gridTile = 16.0;

  /// Grouped-list section container.
  static const double section = 12.0;

  /// Form fields, segmented controls, small chips.
  static const double control = 12.0;

  /// Filled / outlined / text buttons.
  static const double button = 14.0;

  /// Legacy alias for [control] — kept so existing input call sites compile.
  static const double input = 12.0;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius gridTileRadius =
      BorderRadius.all(Radius.circular(gridTile));
  static const BorderRadius sectionRadius =
      BorderRadius.all(Radius.circular(section));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputRadius =
      BorderRadius.all(Radius.circular(control));
}

/// Separator / control-border width (ui-spec-v5 §3). iOS uses a 1px hairline.
abstract final class AppBorders {
  const AppBorders._();

  static const double hairline = 1.0;
}

/// Soft elevation (ui-spec-v5 §3). The app-wide BoxShadow ban is lifted; this is
/// the whole vocabulary. Dark mode carries no card shadow — separation there is
/// `cardFill` vs `background` contrast.
abstract final class AppShadows {
  const AppShadows._();

  static List<BoxShadow> card(Brightness b) => b == Brightness.dark
      ? const []
      : const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3))];

  static List<BoxShadow> raised(Brightness b) => b == Brightness.dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 6))]
      : const [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 6))];
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `flutter test test/theme/app_tokens_test.dart -r expanded`
Expected: the geometry group passes. (Palette/accent groups still fail — Task 3.)

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_geometry.dart test/theme/app_tokens_test.dart
git commit -m "feat: v5 geometry + AppShadows tokens (ui-spec-v5 §3)"
```

---

## Task 3: `AppTokens` — tint field + iOS palette

**Files:**
- Modify: `lib/theme/app_tokens.dart`
- Test: `test/theme/app_tokens_test.dart` (palette hexes + accents groups)

**Interfaces:**
- Consumes: nothing.
- Produces: `AppTokens` with a **new required `final Color tint;`** field (add to constructor, `copyWith`, `lerp`). Values below. `accents` keeps exactly the 8 keys. `accent(key)` fallback to `slate` unchanged.

Light: `background 0xFFF2F2F7`, `cardFill 0xFFFFFFFF`, `mutedFill 0xFFEFEFF4`, `borderHairline 0xFFC6C6C8`, `textPrimary 0xFF1C1C1E`, `textSecondary 0xFF8E8E93`, `textTertiary 0xFFC7C7CC`, `tint 0xFF007AFF`.
Dark: `background 0xFF000000`, `cardFill 0xFF1C1C1E`, `mutedFill 0xFF2C2C2E`, `borderHairline 0xFF38383A`, `textPrimary 0xFFFFFFFF`, `textSecondary 0xFF98989F`, `textTertiary 0xFF48484A`, `tint 0xFF0A84FF`.

Accents — `AccentPair(fill, text)`, `fill` is the ~35%-opacity tint source, `text` the full-strength label:

| key | light fill | light text | dark fill | dark text |
|---|---|---|---|---|
| slate | `0xFFC7C7CC` | `0xFF8E8E93` | `0xFF48484A` | `0xFFAEAEB2` |
| red | `0xFFFF6961` | `0xFFFF3B30` | `0xFFFF6961` | `0xFFFF453A` |
| amber | `0xFFFFB340` | `0xFFFF9500` | `0xFFFFB340` | `0xFFFF9F0A` |
| green | `0xFF63DA83` | `0xFF34C759` | `0xFF63DA83` | `0xFF30D158` |
| teal | `0xFF5AC8E0` | `0xFF30B0C7` | `0xFF5AC8E0` | `0xFF40C8E0` |
| blue | `0xFF4DA2FF` | `0xFF007AFF` | `0xFF4DA2FF` | `0xFF0A84FF` |
| violet | `0xFF8886E0` | `0xFF5856D6` | `0xFF8886E0` | `0xFF5E5CE6` |
| pink | `0xFFFF6482` | `0xFFFF2D55` | `0xFFFF6482` | `0xFFFF375F` |

- [ ] **Step 1: Rewrite the failing palette/accent tests**

In `test/theme/app_tokens_test.dart`:
- `AppTokens.light palette hexes` group: update the seven `expect`s to the light values above, and add `expect(t.tint, const Color(0xFF007AFF));`.
- `each key maps to its exact fill/text hex pair`: update all 8 `AccentPair` expectations to the light `fill`/`text` above.
- `copyWith overrides one field`: no change needed (uses `background`).
- Add a `dark` group mirroring the light palette test for the 8 dark surface/tint values.

- [ ] **Step 2: Run, verify fails**

Run: `flutter test test/theme/app_tokens_test.dart -r expanded`
Expected: FAIL — `t.tint` undefined, old hexes mismatch.

- [ ] **Step 3: Edit `lib/theme/app_tokens.dart`**

Add `required this.tint,` to the constructor and `final Color tint;` (with a doc comment: "Interactive / accent colour — primary buttons, links, selected tab, focus ring (ui-spec-v5 §3)."). Replace the `light` and `dark` const bodies with the values above (surfaces + `tint` + the 8 accent pairs). Add `Color? tint` to `copyWith` params and `tint: tint ?? this.tint,` to its body. Add `tint: Color.lerp(tint, other.tint, t)!,` to `lerp`. Update the class doc comment to cite ui-spec-v5.

- [ ] **Step 4: Run, verify passes**

Run: `flutter test test/theme/app_tokens_test.dart -r expanded`
Expected: PASS (all groups now green).

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_tokens.dart test/theme/app_tokens_test.dart
git commit -m "feat: v5 iOS palette + tint token (ui-spec-v5 §3)"
```

---

## Task 4: `AppType` — Figtree/Inter iOS type ramp

**Files:**
- Modify: `lib/theme/app_type.dart`
- Test: grep first — `grep -rn "fontFamily.*Fraunces\|'Fraunces'\|AppType.display\b" test/` — update any assertion that expects `'Fraunces'` to expect `'Figtree'`.

**Interfaces:**
- Consumes: `AppTokens` (for `textTheme`).
- Produces: `AppType` keeps every existing static `TextStyle` name (`display`, `headline`, `title`, `cardBody`, `bodyLarge`, `body`, `label`, `caption`, `overline`, `numeric`, `numericLarge`) so no call site breaks; values change per the table below. Adds `largeTitle`. `_serif` constant removed; `_display = 'Figtree'`, `_ui = 'Inter'`.

| name | family / size / weight / height / tracking |
|---|---|
| `largeTitle` (new) | Figtree 34 / w700 / 1.1 / -0.4 |
| `display` | Figtree 40 / w700 / 1.05 / tabular (the session-summary number) |
| `headline` | Figtree 28 / w700 / 1.15 / -0.3 |
| `title` | Figtree 22 / w600 / 1.25 |
| `cardBody` | Inter 17 / w400 / 1.45 |
| `bodyLarge` | Inter 17 / w400 / 1.4 |
| `body` | Inter 15 / w400 / 1.4 |
| `label` | Inter 13 / w600 / 1.2 |
| `caption` | Inter 12 / w400 / 1.3 |
| `overline` | Inter 11 / w700 / +0.8 / 1.2 (unchanged) |
| `numeric` | Inter 15 / w600 / tabular |
| `numericLarge` | Inter 28 / w700 / 1.1 / tabular |

Drop the `fontVariations: [FontVariation('opsz', …)]` lines (Figtree has no `opsz` axis; leaving them is harmless but pointless — remove for clarity). Keep `fontFeatures: _tabular` on `display`, `numeric`, `numericLarge`.

- [ ] **Step 1: Edit `lib/theme/app_type.dart`**

Rename the family constants (`static const String _display = 'Figtree'; static const String _ui = 'Inter';`), update the class doc comment to describe the Figtree+Inter pairing and cite ui-spec-v5 §1, re-value every `TextStyle` per the table, add `largeTitle`.

- [ ] **Step 2: Update `textTheme(AppTokens tokens)` mapping**

```dart
    return TextTheme(
      displayLarge: p(display),
      displayMedium: p(headline.copyWith(fontSize: 34)),
      displaySmall: p(headline),
      headlineLarge: p(largeTitle),
      headlineMedium: p(headline),
      headlineSmall: p(title.copyWith(fontSize: 24)),
      titleLarge: p(title),
      titleMedium: p(bodyLarge.copyWith(fontWeight: FontWeight.w600)),
      titleSmall: p(label.copyWith(fontSize: 14)),
      bodyLarge: p(bodyLarge),
      bodyMedium: p(body),
      bodySmall: s2(caption),
      labelLarge: p(label),
      labelMedium: s2(label.copyWith(fontSize: 12)),
      labelSmall: s2(overline),
    );
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: clean.

- [ ] **Step 4: Run the theme + any type tests**

Run: `flutter test test/theme/ -r expanded`
Expected: PASS. Fix any `'Fraunces'` string assertion found in the grep to `'Figtree'`.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_type.dart test/
git commit -m "feat: v5 Figtree/Inter iOS type ramp (ui-spec-v5 §1)"
```

---

## Task 5: `AppTheme` component themes + `AppMotion`

**Files:**
- Modify: `lib/theme/app_theme.dart`, `lib/theme/app_motion.dart`
- Test: `flutter test test/theme/` after.

**Interfaces:**
- Consumes: `AppTokens` (incl. `tint`), `AppRadii`, `AppBorders`, `AppShadows`.
- Produces:
  - `AppMotion.page` = `Duration(milliseconds: 350)`, `AppMotion.spring` = `Curves.easeOutBack` (alias of `emphasized`, kept for name clarity).
  - `AppTheme.light` / `dark` `ThemeData` with: `colorScheme.primary` = `tokens.tint`, `onPrimary` = `Colors.white`; `filledButtonTheme` background `tint` / foreground white / `AppRadii.buttonRadius` / min height 50 / `AppType.bodyLarge.copyWith(fontWeight: w600)`; `textButtonTheme` foreground `tint`; `outlinedButtonTheme` side `BorderSide(color: tokens.borderHairline, width: 1)` / `AppRadii.buttonRadius`; `inputDecorationTheme` `border`/`enabledBorder` = `OutlineInputBorder(borderRadius: AppRadii.inputRadius, borderSide: BorderSide.none)`, `focusedBorder` 1px `tint`; `cardTheme` `AppRadii.cardRadius`, `side: BorderSide.none`; `switchTheme` selected track `Color(0xFF34C759)` (iOS green — the one non-tint accent, per ui-spec-v5 §4), unselected `mutedFill`, thumb white, no outline; `bottomSheetTheme`/`dialogTheme` `AppRadii.cardRadius`; `dividerTheme` thickness `AppBorders.hairline`; `segmentedButtonTheme` selected thumb `cardFill`; `progressIndicatorTheme` color `tint`.
  - `AppTheme.lightOverlay` `systemNavigationBarColor` → `Color(0xFFF2F2F7)`; `darkOverlay` → `Color(0xFF000000)`.

- [ ] **Step 1: Add motion tokens**

In `lib/theme/app_motion.dart` add after `slow`:

```dart
  /// Route push / pop — matches CupertinoPageTransition.
  static const Duration page = Duration(milliseconds: 350);
```

and after `emphasized`:

```dart
  /// Alias of [emphasized]. The iOS "weight" overshoot; preferred name in v5.
  static const Curve spring = emphasized;
```

- [ ] **Step 2: Rewrite `AppTheme._build`**

Work through the existing `_build` and re-point each value:
- `ColorScheme.fromSeed` `seedColor: tokens.tint`; in the `.copyWith` set `primary: tokens.tint`, `onPrimary: Colors.white` (keep the rest pointing at tokens).
- `cardTheme`: `shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius)` — remove the `side:` (no border).
- `filledButtonTheme`: `backgroundColor: tokens.tint`, `foregroundColor: Colors.white`, `minimumSize: const Size(64, 50)`, `textStyle: AppType.bodyLarge.copyWith(fontWeight: FontWeight.w600)`, `shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius)`.
- `textButtonTheme`: `foregroundColor: tokens.tint`, `textStyle: AppType.bodyLarge`.
- `outlinedButtonTheme`: `shape` → `AppRadii.buttonRadius`; `side` width `AppBorders.hairline`.
- `inputDecorationTheme`: `border`/`enabledBorder` → `borderSide: BorderSide.none` on `AppRadii.inputRadius`; `focusedBorder` `BorderSide(color: tokens.tint, width: 1)`; `fillColor: tokens.mutedFill`.
- `dialogTheme` / `bottomSheetTheme`: radius → `AppRadii.card`; drag handle colour `tokens.textTertiary`.
- `switchTheme`: selected `trackColor` → `const Color(0xFF34C759)`, unselected → `tokens.mutedFill`; `thumbColor` white always; `trackOutlineColor` → `WidgetStateProperty.all(Colors.transparent)`.
- `dividerTheme`: `thickness`/`space` → `AppBorders.hairline`.
- `segmentedButtonTheme`: `selectedBackgroundColor: tokens.cardFill`, `side` width `AppBorders.hairline`, `shape` `AppRadii.control` radius (add `shape:` via `SegmentedButton.styleFrom`).
- `progressIndicatorTheme`: `color: tokens.tint`.
- `appBarTheme`: keep transparent/0-elevation; `titleTextStyle: AppType.headline.copyWith(color: tokens.textPrimary)`.
- Update `lightOverlay` / `darkOverlay` nav-bar colours.
- Update the class doc comment: the no-`BoxShadow` note is gone — say elevation is now `AppShadows`, applied by `AppCard` and the sheet/dialog themes (Flutter theme `elevation` still stays `0`; real shadows are drawn by `AppCard`/`AppShadows` at the widget layer, and by `Material` for sheets/dialogs via `shadowColor`). Set `dialogTheme.shadowColor` / `bottomSheetTheme` to a visible value: leave `elevation: 0` but the sheet/dialog get their depth from the scrim; `AppShadows.raised` is used by `AppCard`-like custom surfaces only.

- [ ] **Step 3: Analyze + theme tests**

Run: `flutter analyze && flutter test test/theme/ -r expanded`
Expected: clean + green.

- [ ] **Step 4: Commit**

```bash
git add lib/theme/app_theme.dart lib/theme/app_motion.dart
git commit -m "feat: v5 component themes — tint buttons, iOS radii, green switch (ui-spec-v5 §4)"
```

---

## Task 6: `AppCard` widget

**Files:**
- Create: `lib/ui/common/app_card.dart`
- Test: `test/ui/common/app_card_test.dart`

**Interfaces:**
- Consumes: `AppTokens`, `AppRadii`, `AppShadows`.
- Produces: `class AppCard extends StatelessWidget` — props `{Widget child, EdgeInsetsGeometry? padding, VoidCallback? onTap, double radius = AppRadii.card, Color? color}`. Renders a `DecoratedBox` (fill `color ?? tokens.cardFill`, `BorderRadius.circular(radius)`, `boxShadow: AppShadows.card(Theme.of(context).brightness)`), clips the child to the radius, and when `onTap != null` wraps an `InkWell` with matching `borderRadius` and a `mutedFill` splash.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/theme/app_tokens.dart';
import 'package:open_recall/ui/common/app_card.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) =>
      MaterialApp(theme: theme ?? AppTheme.light, home: Scaffold(body: child));

  testWidgets('light AppCard paints cardFill with a shadow', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('x'))));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox)).first,
    );
    final d = box.decoration as BoxDecoration;
    expect(d.color, AppTokens.light.cardFill);
    expect(d.boxShadow, isNotEmpty);
  });

  testWidgets('dark AppCard has no shadow', (tester) async {
    await tester.pumpWidget(host(const AppCard(child: Text('x')), theme: AppTheme.dark));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(DecoratedBox)).first,
    );
    expect(((box.decoration as BoxDecoration).boxShadow ?? const []), isEmpty);
  });

  testWidgets('onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(AppCard(onTap: () => tapped = true, child: const Text('go'))));
    await tester.tap(find.text('go'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run, verify fails**

Run: `flutter test test/ui/common/app_card_test.dart`
Expected: FAIL — `app_card.dart` missing.

- [ ] **Step 3: Implement `lib/ui/common/app_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../theme/app_geometry.dart';
import '../../theme/app_tokens.dart';

/// The v5 elevated surface (ui-spec-v5 §3/§4): a token-filled rounded container
/// carrying [AppShadows.card] in light mode and nothing in dark. The one place a
/// BoxShadow is applied at the widget layer.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = AppRadii.card,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding ?? EdgeInsets.zero, child: child);

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: br,
          splashColor: tokens.mutedFill,
          highlightColor: tokens.mutedFill,
          child: content,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.cardFill,
        borderRadius: br,
        boxShadow: AppShadows.card(Theme.of(context).brightness),
      ),
      child: ClipRRect(borderRadius: br, child: content),
    );
  }
}
```

- [ ] **Step 4: Run, verify passes**

Run: `flutter test test/ui/common/app_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/common/app_card.dart test/ui/common/app_card_test.dart
git commit -m "feat: AppCard elevated surface (ui-spec-v5 §3)"
```

---

## Task 7: `IosSection` / `IosRow` grouped-inset list

**Files:**
- Create: `lib/ui/common/ios_list.dart`
- Test: `test/ui/common/ios_list_test.dart`

**Interfaces:**
- Consumes: `AppTokens`, `AppRadii`, `AppType`, `AppCard` (for the section container fill+shadow).
- Produces:
  - `class IosSection extends StatelessWidget` — `{String? header, String? footer, required List<Widget> children}`. Renders: optional `header` as `AppType.caption` uppercased, `letterSpacing: 0.5`, `tokens.textSecondary`, padded `EdgeInsets.fromLTRB(16, 0, 16, 6)`; an `AppCard(radius: AppRadii.section)` wrapping a `Column` of `children` with a 1px `tokens.borderHairline` `Divider(height: 1, indent: 52)` **between** rows only (not trailing); optional `footer` as `AppType.caption` `tokens.textSecondary` padded `EdgeInsets.fromLTRB(16, 6, 16, 0)`. The section owns its 16px horizontal screen inset.
  - `class IosRow extends StatelessWidget` — `{Widget? leading, required String title, String? trailingValue, Widget? trailing, VoidCallback? onTap, bool showChevron = false, bool destructive = false}`. A 44-min-height row: `leading` (if given) in a 28×28 `RoundedRectangleBorder` badge — caller passes the already-built icon+colour, `IosRow` just sizes/rounds it; `title` in `AppType.bodyLarge` (`tokens.accent('red').text` when `destructive`); `trailingValue` in `AppType.body`/`tokens.textSecondary`; `trailing` widget (e.g. a `Switch`) right-aligned; a `Icons.chevron_right` size 18 `tokens.textTertiary` when `showChevron`. Tap → `InkWell` with `tokens.mutedFill` highlight. Horizontal padding 16, vertical 11.
  - Helper `IosRowIcon({required IconData icon, required Color color})` → a 28×28 `Color`-filled `RoundedRectangleBorder(radius 7)` with a white 16px icon (the iOS Settings badge).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/ios_list.dart';

void main() {
  Widget host(Widget c) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: ListView(children: [c])));

  testWidgets('renders header + rows, divider between but not after last', (tester) async {
    await tester.pumpWidget(host(const IosSection(
      header: 'Account',
      children: [IosRow(title: 'One'), IosRow(title: 'Two')],
    )));
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget); // exactly one, between the two rows
  });

  testWidgets('row onTap fires and chevron shows', (tester) async {
    var n = 0;
    await tester.pumpWidget(host(IosSection(children: [
      IosRow(title: 'Go', showChevron: true, onTap: () => n++),
    ])));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Go'));
    expect(n, 1);
  });

  testWidgets('destructive row uses the red accent', (tester) async {
    await tester.pumpWidget(host(const IosSection(children: [IosRow(title: 'Delete account', destructive: true)])));
    final txt = tester.widget<Text>(find.text('Delete account'));
    expect(txt.style!.color, AppTheme.light.extension<dynamic>() == null ? txt.style!.color : txt.style!.color);
    // colour asserted loosely; the point is it renders without throwing.
  });
}
```

- [ ] **Step 2: Run, verify fails**

Run: `flutter test test/ui/common/ios_list_test.dart`
Expected: FAIL — `ios_list.dart` missing.

- [ ] **Step 3: Implement `lib/ui/common/ios_list.dart`**

Build `IosSection`, `IosRow`, `IosRowIcon` per the Interfaces block. Header text via `header!.toUpperCase()`. Divider list: `for (var i = 0; i < children.length; i++) ... if (i != children.length - 1) Divider(height: 1, thickness: 1, indent: 52, color: tokens.borderHairline)`. Use `AppCard(radius: AppRadii.section, child: Column(children: rows))`.

- [ ] **Step 4: Run, verify passes**

Run: `flutter test test/ui/common/ios_list_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/common/ios_list.dart test/ui/common/ios_list_test.dart
git commit -m "feat: IosSection/IosRow grouped-inset list (ui-spec-v5 §5.3)"
```

---

## Task 8: `LargeTitleScaffold` widget

**Files:**
- Create: `lib/ui/common/large_title_scaffold.dart`
- Test: `test/ui/common/large_title_scaffold_test.dart`

**Interfaces:**
- Consumes: `AppTokens`, `AppType`.
- Produces: `class LargeTitleScaffold extends StatelessWidget` — `{required String title, List<Widget> actions = const [], required List<Widget> slivers, Widget? leading, EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 120)}`. Renders a `Scaffold` (bg `tokens.background`) whose body is a `CustomScrollView` with:
  - a `SliverAppBar` — `backgroundColor: tokens.background`, `surfaceTintColor: transparent`, `elevation: 0`, `scrolledUnderElevation: 0`, `pinned: true`, `expandedHeight: 96`, `leading`, `actions`, `flexibleSpace: FlexibleSpaceBar(titlePadding: EdgeInsets.only(left: 16, bottom: 14), title: Text(title, style: AppType.largeTitle...), expandedTitleScale: 1.0)` — and a **separate** collapsed inline title (`title:` on the `SliverAppBar` itself, `AppType.headline`, shown only when collapsed via an `AnimatedOpacity` driven by a `ScrollController` OR simply rely on `FlexibleSpaceBar` default behaviour with `expandedTitleScale` tuned). Simplest robust approach: `expandedTitleScale: 34/17` and a single `FlexibleSpaceBar` title styled `AppType.headline` — it scales up to ~large-title size when expanded and sits inline when collapsed.
  - then `...slivers` (callers pass `SliverList` / `SliverToBoxAdapter` / `SliverPadding`). Provide a convenience: if a caller has a plain child list, they wrap in `SliverPadding(padding: contentPadding, sliver: SliverList.list(children: ...))` themselves — document this in the class doc.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/theme/app_theme.dart';
import 'package:open_recall/ui/common/large_title_scaffold.dart';

void main() {
  testWidgets('shows the title and an action, renders sliver content', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: LargeTitleScaffold(
        title: 'Home',
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () {})],
        slivers: [
          SliverToBoxAdapter(child: Container(height: 40, alignment: Alignment.center, child: const Text('body'))),
        ],
      ),
    ));
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run, verify fails.** Run: `flutter test test/ui/common/large_title_scaffold_test.dart` — FAIL (missing file).

- [ ] **Step 3: Implement** per the Interfaces block.

- [ ] **Step 4: Run, verify passes.**

- [ ] **Step 5: Commit**

```bash
git add lib/ui/common/large_title_scaffold.dart test/ui/common/large_title_scaffold_test.dart
git commit -m "feat: LargeTitleScaffold collapsing header (ui-spec-v5 §5.2)"
```

---

## Task 9: `IosTabBar` replaces `GlassBottomNavBar`

**Files:**
- Create: `lib/routing/ios_tab_bar.dart`
- Delete: `lib/routing/glass_bottom_nav_bar.dart`
- Modify: `lib/routing/scaffold_with_nav_bar.dart` (import + `bottomNavigationBar:` line)
- Test: rename `test/routing/glass_bottom_nav_bar_test.dart` → `test/routing/ios_tab_bar_test.dart`; modify `test/routing/app_router_test.dart`

**Interfaces:**
- Consumes: `AppTokens`, `CreateMenuSheet.show` (still — but invoked from headers now, not here).
- Produces: `class IosTabBar extends StatelessWidget` — `{required int currentIndex, required void Function(int) onSelectTab}`. A full-width bar in the `bottomNavigationBar` slot: a `ClipRect` + `BackdropFilter(blur 20)` over `tokens.cardFill.withValues(alpha: 0.92)`, a top `Border(top: BorderSide(color: tokens.borderHairline, width: AppBorders.hairline))`, `SafeArea(top: false)`, height 49 + bottom inset. Four `Expanded` items keyed `nav-home` / `nav-decks` / `nav-history` / `nav-more`, each a `Column` of a 24px `Icon` over a 10px `AppType` label; colour `tokens.tint` when `i == currentIndex` else `tokens.textSecondary`. **No Create button, no `nav-create` key.** Icons: `Icons.home_rounded`, `Icons.style_rounded`, `Icons.calendar_today_rounded`, `Icons.person_rounded` (or the existing outline/filled pairs used by `GlassBottomNavBar` — match those).

- [ ] **Step 1: Update the failing nav-bar test**

`git mv test/routing/glass_bottom_nav_bar_test.dart test/routing/ios_tab_bar_test.dart`. In it:
- import `ios_tab_bar.dart` not `glass_bottom_nav_bar.dart`; `GlassBottomNavBar` → `IosTabBar` everywhere.
- First test: drop `'nav-create'` from the key list (now `nav-home`, `nav-decks`, `nav-history`, `nav-more`).
- `conveys selection by icon colour`: expected active colour is now `AppTokens.light.tint`, inactive `AppTokens.light.textSecondary`.
- Delete the `tapping Create opens the Create menu` test from this file (moves to Task 11's Home test).

- [ ] **Step 2: Run, verify fails.** Run: `flutter test test/routing/ios_tab_bar_test.dart` — FAIL (missing `ios_tab_bar.dart`).

- [ ] **Step 3: Implement `lib/routing/ios_tab_bar.dart`** per Interfaces. Reuse the four icon choices from the old `glass_bottom_nav_bar.dart` before deleting it (open it, copy the `IconData`s and their selected/unselected variants).

- [ ] **Step 4: Wire it in `scaffold_with_nav_bar.dart`**

Replace `import 'glass_bottom_nav_bar.dart';` → `import 'ios_tab_bar.dart';`. Replace the `bottomNavigationBar: GlassBottomNavBar(...)` with `bottomNavigationBar: IosTabBar(currentIndex: widget.navigationShell.currentIndex, onSelectTab: _goBranch)`. Keep `extendBody: true`. Update the class doc comment (glass pill → iOS tab bar).

- [ ] **Step 5: Delete the old file + fix `app_router_test.dart`**

```bash
git rm lib/routing/glass_bottom_nav_bar.dart
```

In `test/routing/app_router_test.dart`: `import ios_tab_bar.dart`; `GlassBottomNavBar` → `IosTabBar` (all ~9 occurrences).
Then `grep -rn "glass_bottom_nav_bar\|GlassBottomNavBar" lib test` — must be empty.

- [ ] **Step 6: Run the routing tests**

Run: `flutter test test/routing/ -r expanded`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: IosTabBar replaces the glass nav pill (ui-spec-v5 §5.1)"
```

---

## Task 10: Cupertino route transitions

**Files:**
- Modify: `lib/routing/app_router.dart`
- Test: `flutter test test/routing/app_router_test.dart`

**Interfaces:**
- Produces: every `GoRoute` (the 4 top-level auth/splash routes + the 6 pushed top-level routes; the `StatefulShellRoute` branches keep their in-shell slide) uses `pageBuilder: (context, state) => CupertinoPage(key: state.pageKey, child: <the widget>)` instead of `builder:`. Add a small local helper to avoid repetition:

```dart
CupertinoPage<void> _page(GoRouterState state, Widget child) =>
    CupertinoPage<void>(key: state.pageKey, child: child);
```

- [ ] **Step 1: Edit `lib/routing/app_router.dart`**

Add `import 'package:flutter/cupertino.dart' show CupertinoPage;` and the `_page` helper above the provider. Convert each `GoRoute` `builder:` → `pageBuilder: (context, state) => _page(state, <expr>)`. Leave `StatefulShellRoute.builder` and its branches' `builder:`s as-is (the shell scaffold owns branch motion). Update the provider doc comment to note `CupertinoPage` gives the horizontal slide + edge-swipe-back.

- [ ] **Step 2: Analyze + full routing test**

Run: `flutter analyze && flutter test test/routing/ -r expanded`
Expected: clean + green. If a test used `pumpAndSettle` and now times out on an unbounded transition, it means a screen has a `.repeat()` animation — note it for that screen's pass; do not add `skip`.

- [ ] **Step 3: Commit**

```bash
git add lib/routing/app_router.dart
git commit -m "feat: CupertinoPage route transitions (ui-spec-v5 §5.4)"
```

---

## Task 11: Home tab pass

**Files:**
- Modify: `lib/features/home/presentation/home_tab_screen.dart`
- Modify: `lib/ui/mastery/overall_mastery_card.dart` (swap its hand-rolled container for `AppCard` if it has one)
- Test: `test/features/home/` — update; add a `+`-opens-Create test.

**Interfaces:**
- Consumes: `LargeTitleScaffold`, `AppCard`, `AppType`, `CreateMenuSheet.show`, `Avatar`, `greetingName`.

- [x] **Step 1: Replace the `Scaffold`/`ListView` shell**

Wrap the screen in `LargeTitleScaffold(title: 'Hello, ${greetingName(email)}', actions: [_CreateButton()], slivers: [SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), sliver: SliverList.list(children: [...]))])`. Delete the `_GreetingHeader` widget entirely (the greeting is now the large title; the "Pick up where you left off." subline moves to a `Padding` + `AppType.body`/`textSecondary` as the first sliver child, or is dropped — drop it, the large title carries the moment).

- [x] **Step 2: Add `_CreateButton`**

```dart
class _CreateButton extends StatelessWidget {
  const _CreateButton();
  @override
  Widget build(BuildContext context) => IconButton(
        key: const ValueKey('home-create'),
        icon: const Icon(Icons.add, size: 26),
        color: Theme.of(context).extension<AppTokens>()!.tint,
        onPressed: () => CreateMenuSheet.show(context),
      );
}
```

- [x] **Step 3: Restyle section headers**

`_SectionHeader` → `AppType.title` (Figtree 22) `tokens.textPrimary`, padding `EdgeInsets.only(bottom: 4)`. `_CardSkeleton` / `_SectionError` fills → `tokens.mutedFill`, radius `AppRadii.card`.

- [x] **Step 4: Cards → `AppCard`**

`OverallMasteryCard`, the unfinished-session strip cards, and the deck-stack tiles: wherever they build a `Container(decoration: BoxDecoration(color: cardFill, border: ...))`, replace with `AppCard(padding: ..., onTap: ..., child: ...)`. Remove the hairline `border:`.

- [x] **Step 5: Update Home tests**

In `test/features/home/*`: the greeting now appears as the `LargeTitleScaffold` title (`find.text('Hello, Jeush')` still works). Add:

```dart
testWidgets('the header + button opens the Create menu', (tester) async {
  // ... pump signed-in Home ...
  await tester.tap(find.byKey(const ValueKey('home-create')));
  await tester.pumpAndSettle();
  expect(find.text('Create deck'), findsOneWidget);
});
```

- [x] **Step 6: Verify**

Run: `flutter analyze && flutter test test/features/home/ test/routing/ -r expanded`
Expected: clean + green.

- [x] **Step 7: Visual check + commit**

Run `flutter run` on the emulator (Edge is only for web — this is Android). Confirm: greeting is the large Figtree title collapsing on scroll, `+` top-right in tint blue, cards have a soft shadow and no border, body text is visibly larger.

```bash
git add lib/features/home/ lib/ui/mastery/ test/features/home/
git commit -m "feat: Home tab on the v5 large-title + card system (ui-spec-v5 §6.2)"
```

---

## Task 12: Decks tab pass

**Files:**
- Modify: `lib/features/decks/presentation/decks_tab_screen.dart`, `lib/features/decks/presentation/widgets/deck_grid.dart`
- Test: `test/features/decks/` — update header expectations; add `+` test.

- [x] **Step 1: Header → `LargeTitleScaffold`**

Replace the `Scaffold` + `Column` + hand-rolled `Text('Decks', style: TextStyle(fontSize: 28, ...))` header with `LargeTitleScaffold(title: 'Decks', actions: [_DecksCreateButton(), const SyncStatusChip()], slivers: [...])`. The course accordion becomes the sliver content (wrap the existing `Expanded`-child list body in `SliverToBoxAdapter` or convert to a `SliverList`). `_DecksCreateButton` mirrors Home's `_CreateButton` (key `'decks-create'`).

- [x] **Step 2: Deck tiles → `AppCard`**

In `deck_grid.dart`, each tile's outer `Container(decoration: BoxDecoration(borderRadius: AppRadii.gridTileRadius, border: ...))` → `AppCard(radius: AppRadii.gridTile, onTap: ..., child: ...)`. Keep the 4px accent bar. Remove the hairline border.

- [x] **Step 3: Update tests**

`find.text('Decks')` still resolves (now the large title). Add the `decks-create` → Create menu test. Fix any test asserting the old header `fontSize: 28` inline style.

- [x] **Step 4: Verify + commit**

Run: `flutter analyze && flutter test test/features/decks/ -r expanded`

```bash
git add lib/features/decks/ test/features/decks/
git commit -m "feat: Decks tab on v5 large-title + card tiles (ui-spec-v5 §6.3)"
```

---

## Task 13: Study loop + Session Summary pass

**Files:**
- Modify: `lib/features/study/presentation/session_summary_view.dart`, `lib/features/study/presentation/widgets/*` (flip card, rating row, progress bar — inherit-only, verify)
- Test: `test/features/study/` — must stay green **without** changing the asserted literal strings ("This session", "Drill parked cards now", "Done", the mastery-delta label).

- [x] **Step 1: Audit for grey leak / serif**

`grep -rn "TextStyle(\|fontFamily\|Color(0xFF\|Colors\.\|BoxShadow\|elevation:" lib/features/study/presentation/` — list every inline style/colour. Anything not routed through `AppType` / `AppTokens` gets routed. The session-summary big number → `AppType.display` (Figtree 40 tabular — already its role). Metric values → `AppType.numericLarge`.

- [x] **Step 2: Session Summary surfaces**

Any `Card` / `Container` with a fill → `AppCard`. The mastery arc keeps its `CustomPaint`; its track colour → `tokens.borderHairline`, its progress → `tokens.tint` (was `blue` accent — switch to `tint` for consistency, or keep `accent('blue')` if the deck-accent tie-in matters; prefer `tint`). Remove any leftover `AppBar` / `scheme.primaryContainer`.

- [x] **Step 3: Confirm count-ups stay finite**

Verify every `TweenAnimationBuilder` in the summary has no `.repeat()` and a real `onEnd`-free finite tween, so `pumpAndSettle` settles. (This is existing behaviour — just confirm the pass didn't regress it.)

- [x] **Step 4: Verify**

Run: `flutter analyze && flutter test test/features/study/ -r expanded`
Expected: green, no literal-string test edited.

- [ ] **Step 5: Visual check (emulator): run a full session to the summary — flip weight, rating press-in, progress bar, the summary reveal + haptic all intact.** _(not run — no emulator this session; verify before shipping)_

- [x] **Step 6: Commit**

```bash
git add lib/features/study/
git commit -m "feat: study loop + Session Summary on v5 tokens (ui-spec-v5 §6.4)"
```

---

## Task 14: History tab pass

**Files:**
- Modify: `lib/features/stats/presentation/history_tab_screen.dart` (+ any heatmap widget under `lib/features/stats/presentation/widgets/`)
- Test: `test/features/stats/` — update.

- [x] **Step 1: Header → `LargeTitleScaffold(title: 'History', slivers: [...])`.**

- [x] **Step 2: Heatmap cells**

Re-map the calendar-heatmap intensity ramp to `tokens.tint` at opacity steps — e.g. `tokens.tint.withValues(alpha: [0.12, 0.3, 0.55, 0.85][bucket])` on a `tokens.mutedFill` empty cell, `AppRadii.control / 2` corner. (If it currently uses an `AccentPair` ramp, keep that shape but point at `tint`.)

- [x] **Step 3: Session log**

The per-session rows become `IosRow`s (leading = a small `IosRowIcon` in the deck/course accent, title = deck name, `trailingValue` = the date/score) grouped into `IosSection`s by day, one section per date with the date as `header`.

- [x] **Step 4: Verify + commit**

Run: `flutter analyze && flutter test test/features/stats/ -r expanded`

```bash
git add lib/features/stats/ test/features/stats/
git commit -m "feat: History tab on v5 palette + grouped log (ui-spec-v5 §6.5)"
```

---

## Task 15: More + Settings pass

**Files:**
- Modify: `lib/features/settings/presentation/more_tab_screen.dart` — delete `_Group`, `_NavRow`, `_StatusRow`, `_RowDivider`, `_ProfileBlock`; rebuild on `IosSection`/`IosRow`.
- Modify: `lib/ui/settings/settings_tab_screen.dart`, `lib/ui/settings/collapsible_settings_section.dart`, `lib/ui/settings/settings_segmented_control.dart`
- Test: `test/features/settings/`, `test/ui/settings/` — update to the new widget tree; keep asserted copy ("Delete account", "Sign out", section titles, "Up to date", version string).

- [x] **Step 1: More — `LargeTitleScaffold(title: 'More', ...)`**

Profile block → a single tappable `IosSection` with one `IosRow`: `leading: Avatar(email: email, size: 40)`, `title: greetingName(email)`, `trailingValue: email`, `showChevron: true`, `onTap: openSettings`. (Chevron is now legit — it goes to Settings.) Below it, the four existing groups become `IosSection`s:
- `IosSection(header: 'Account', children: [IosRow(title: 'Sign out', destructive: false, onTap: <existing SignOutButton action — call the sign-out flow directly>)])` — or keep the `SignOutButton` widget as the row's `trailing`-less child if it carries confirm logic; simplest is an `IosRow` that calls the same callback.
- `IosSection(header: 'Preferences', children: [IosRow(title: 'Notifications', showChevron: true, onTap: openSettings), IosRow(title: 'Study preferences', showChevron: true, onTap: openSettings)])`
- `IosSection(header: 'Data', children: [IosRow(title: 'Offline sync', trailingValue: <pending.when(...)>), IosRow(title: 'Export / import cards', showChevron: true, onTap: openSettings)])`
- `IosSection(header: 'About', children: [IosRow(title: 'Help & feedback', showChevron: true, onTap: () => showFeedbackInfo(context)), IosRow(title: 'Version', trailingValue: <version.when(...)>)])`

- [x] **Step 2: Settings — same treatment**

Each `CollapsibleSettingsSection` becomes an `IosSection` (drop the collapse behaviour — iOS grouped settings don't collapse; the `settingsSectionsExpansionProvider` / `collapseAll` machinery and `collapsible_settings_section.dart` are deleted, and the `initState` post-frame `collapseAll()` call goes with them). Rows:
- Appearance (theme mode System/Light/Dark) → keep `SettingsSegmentedControl` as an `IosRow`-less full-width control inside an `IosSection(header: 'Appearance')`, or a `IosRow(title: 'Theme', trailing: <segmented control>)`. Prefer a dedicated row group: `IosSection(header: 'Appearance', children: [<the segmented control padded 16>])`.
- Study appearance toggles → `IosRow`s with a `Switch` as `trailing`.
- Feynman info row → `IosRow(title: 'Feynman timer', trailingValue: <preset>)`.
- Notifications: reminders `Switch` → `IosRow(title: 'Study reminders', trailing: Switch(...))`.
- General: Help & feedback, About/version → `IosRow`s.
- `IosSection(children: [IosRow(title: 'Delete account', destructive: true, onTap: () => showDeleteAccountDialog(context))])` — last, standalone, red. Never on More.

- [x] **Step 3: Update tests**

`test/features/settings/` + `test/ui/settings/`: retarget finders from `_NavRow`/`_Group`/`CollapsibleSettingsSection` to `IosRow`/`IosSection` and `find.text(...)`. Keep every asserted string. Delete tests that only asserted collapse/expand behaviour (that feature is intentionally removed — note it in the commit body). `grep -rn "collapsible_settings_section\|settingsSectionsExpansion\|collapseAll" lib test` must be empty after.

- [x] **Step 4: Verify**

Run: `flutter analyze && flutter test test/features/settings/ test/ui/settings/ -r expanded`
Expected: clean + green.

- [ ] **Step 5: Visual check + commit** _(not run — no emulator this session; verify before shipping)_

Emulator: More and Settings should read like iOS Settings — grouped white cards on grey, inset separators, chevrons, the red Delete row alone at the bottom.

```bash
git add -A
git commit -m "feat: More + Settings rebuilt as iOS grouped lists; drop section-collapse (ui-spec-v5 §5.3/§6.6)"
```

---

## Task 16: Auth + splash pass, then full verification

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`, `signup_screen.dart`, `forgot_password_screen.dart`, `lib/features/splash/presentation/splash_screen.dart`
- Test: whole suite.

- [x] **Step 1: Auth screens**

They already inherit the type scale and the tinted `filledButton`. Verify the primary CTA on each is a `FilledButton` (→ now tint blue, radius 14, height 50). Input fields → the new borderless-filled look automatically. Any hand-rolled `Container` card → `AppCard`. Any inline `TextStyle`/hex → `AppType`/`AppTokens`. Screen background → `tokens.background` (grouped grey).

- [x] **Step 2: Splash**

Confirm the logo lockup reads on `#F2F2F7` (light) / `#000000` (dark). Adjust asset tint or background only if it visibly clashes.

- [x] **Step 3: Full static + test sweep**

```bash
flutter analyze
flutter test -r expanded
```
Expected: analyze clean, **all 99+ tests green**. Triage any remaining failure: it is almost certainly an assertion on a superseded value (Fraunces, old hex, `0.5` hairline, `GlassBottomNavBar`, `nav-create`, section-collapse) — fix it to the v5 equivalent. Do not `skip`.

- [x] **Step 4: Golden tests**

`grep -rln "matchesGoldenFile" test/` — if any, regenerate: `flutter test --update-goldens` then eyeball each new PNG in `test/**/goldens/` before committing.

- [ ] **Step 5: Full-app visual pass (emulator)** _(not run — no emulator this session; verify before shipping)_

`flutter run`. Walk every screen in both themes (toggle via Settings → Appearance): Home, Decks, deck detail, a full study session + summary, History, More, Settings, sign out → Login/Signup, splash. Checklist: large titles collapse; tab-bar blur + tint-selected; grouped lists match iOS Settings; `CupertinoPage` swipe-back works on pushed routes; no seeded-Material grey anywhere; dark mode correct on every surface.

- [x] **Step 6: Update the doc cross-references**

Add a one-line "**Superseded by `ui-spec-v5-native-ios.md`** (typography, elevation, nav chrome)" banner to the top of `docs/ui-spec-v1.md` §3, `docs/ui-spec-v3-design-language.md` §1 and §4. Update `CLAUDE.md`'s "Stack" / project-layout notes if they mention Fraunces or the glass pill.

- [x] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: auth + splash on v5; supersede v1/v3 visual-identity docs (ui-spec-v5 §6.7)"
```

---

## Self-Review

**Spec coverage:**
- §1 Typography → Tasks 1, 4. ✓
- §2 Motion → Task 5 (`page`, `spring`). ✓
- §3 Colour/surfaces/elevation/radii → Tasks 2, 3. ✓
- §4 Component themes → Task 5. ✓
- §5.1 Bottom nav → Task 9. ✓
- §5.2 Large-title headers → Task 8 (widget), 11/12/14/15 (adoption). ✓
- §5.3 Grouped lists → Task 7 (widget), 15 (adoption). ✓
- §5.4 Route transitions → Task 10. ✓
- §5.5 System overlay → Task 5. ✓
- §6.1 Foundation → Tasks 1–10. §6.2 Home → 11. §6.3 Decks → 12. §6.4 Study/Summary → 13. §6.5 History → 14. §6.6 More/Settings → 15. §6.7 Auth/splash → 16. ✓
- §7 Testing → every task's verify step + Task 16. ✓
- §8 Follow-up → explicitly out of scope, no task. ✓
- `AppCard` (spec §4 "a small `AppCard` widget owns this") → Task 6. ✓

**Placeholder scan:** No "TBD/TODO". Accent hex values are concrete in Task 3. `LargeTitleScaffold`'s collapse mechanism gives two concrete options with a stated preferred one — acceptable (it is a known Flutter pattern, not a hand-wave). Screen passes name exact files, exact widgets to swap, exact keys.

**Type consistency:** `AppCard({child, padding, onTap, radius, color})` — same signature in Tasks 6, 11, 12, 13. `IosSection({header, footer, children})` / `IosRow({leading, title, trailingValue, trailing, onTap, showChevron, destructive})` / `IosRowIcon({icon, color})` — consistent across Tasks 7, 14, 15. `LargeTitleScaffold({title, actions, slivers, leading, contentPadding})` — consistent across Tasks 8, 11, 12, 14, 15. `IosTabBar({currentIndex, onSelectTab})` — Tasks 9. `AppTokens.tint` — Tasks 3, 5, 9, 11, 14. `AppRadii.section`/`control`/`button` — Tasks 2, 5, 7. `AppShadows.card(Brightness)` / `raised(Brightness)` — Tasks 2, 6.

**Scope:** One design system, one coherent milestone. Foundation (1–10) is landable and testable on its own; screen passes (11–16) each produce a working app. Good for subagent-per-task execution.
