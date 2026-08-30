# ActiveRecall — Dark Mode Spec (v5)

## 0. Status & relationship to other specs

This document designs **dark mode** for the app. It is the source of truth for
the dark palette, the theme-mode preference, and the system-chrome (status-bar /
navigation-bar) treatment.

It **supersedes** the following "dark mode is deferred / undesigned" notes, which
were placeholders until this spec existed:

- `docs/ui-spec-v1.md` §3.1 ("dark mode is **deferred**, not designed; do not
  invent dark values, flag as a follow-up spec").
- The class doc on `AppTokens` in `lib/theme/app_tokens.dart` ("Dark mode is
  deliberately not modelled here").
- The `AppTheme` doc in `lib/theme/app_theme.dart` ("Dark mode is deferred and
  undesigned — there is deliberately no dark counterpart here").

Everything `ui-spec-v1.md` §3 says about **geometry** (radii, `0.5px` hairline
borders, the no-`BoxShadow` rule) is unchanged and applies identically in dark
mode. Only the palette gains a second set of values.

Nothing here touches the database, models, repositories, or the study engine.
The theme mode is a per-device display choice; like `available_offline` and the
notification toggle (spec §10, §9) it lives in `SharedPreferences`, not on
`profiles`, and is **not** synced.

---

## 1. Token delivery recap

Colour reaches the UI through one channel only: the `AppTokens`
`ThemeExtension`, resolved as `Theme.of(context).extension<AppTokens>()!`, plus
`AppTokens.accent(key)` for a course's accent. Raw colour literals are allowed
**only** inside `app_tokens.dart` (`AppTokens.light` and now `AppTokens.dark`)
and inside `app_theme.dart`'s two `SystemUiOverlayStyle` constants.

Because every screen already resolves through the extension, adding
`AppTokens.dark` and pointing `MaterialApp.darkTheme` at it makes the entire app
theme-aware with no per-widget changes. The audit in §6 covers the handful of
call sites that had slipped a literal past that rule.

---

## 2. Dark palette — surface & text tokens

Derived from the light ramp by inversion: near-black grounds, a slightly lifted
card surface, a low-contrast hairline, and a light-to-dark text ramp.

| Token | Light hex | Dark hex | Usage |
|---|---|---|---|
| `background` | `#FFFFFF` | `#121212` | Screen background |
| `cardFill` | `#FFFFFF` | `#1E1E1E` | Card / tile fill — one step lifted from the ground |
| `mutedFill` | `#F7F7F5` | `#262624` | Stat blocks, inactive segmented-control track |
| `borderHairline` | `#EDEDED` | `#333333` | `0.5px` card / tile / nav borders |
| `textPrimary` | `#1A1A1A` | `#ECECEC` | Headings, primary labels |
| `textSecondary` | `#8A8A8A` | `#9A9A9A` | Captions, metadata, body copy |
| `textTertiary` | `#B0B0B0` | `#6E6E6E` | Placeholder / disabled only |

`#121212` is Material's reference dark surface — dark enough to read as "off",
light enough to avoid OLED smearing on scroll. `cardFill` at `#1E1E1E` and
`mutedFill` at `#262624` give two discernible elevation steps above it without
resorting to shadows (still banned, §3.3 of v1).

### 2.1 WCAG AA verification (body text)

Contrast ratios computed with the WCAG 2.1 relative-luminance formula, text
colour against each ground it is actually drawn on. AA requires **4.5:1** for
normal text, **3:1** for large/bold ≥ 18.66px and for UI components.

| Pair | on `#121212` | on `#1E1E1E` | on `#262624` | Verdict |
|---|---|---|---|---|
| `textPrimary #ECECEC` | 14.4:1 | 14.1:1 | 13.3:1 | AAA |
| `textSecondary #9A9A9A` | 6.0:1 | 5.9:1 | 5.4:1 | AA (AAA for large) |
| `textTertiary #6E6E6E` | 3.3:1 | 3.2:1 | 3.0:1 | placeholder/disabled only — **intentionally sub-AA**, mirrors light `#B0B0B0` (≈2.2:1 on white). Never used for content text. |

`borderHairline #333333` is decorative (a `0.5px` edge) and carries no contrast
requirement; at ≈1.3:1 on `#121212` it reads as a soft seam, which is the
intent.

---

## 3. Dark palette — accent pairs

The 8 `courses.accent_color` keys keep their identity but shift for a dark
ground. Each `AccentPair` still carries:

- **`fill`** — used both at 30–45% opacity as a tint (deck-tile wash, profile
  avatar ring, course stripe) and at full strength as a solid
  (nav Create button, the "Mastered" rating button, the progress-bar fill,
  swatch circles). Dark `fill`s are pushed a little more chromatic than the
  light pastels so they still register as a hue when laid at 40% over `#1E1E1E`.
- **`text`** — full-strength, drawn on `mutedFill`-tinted badges
  (`SeverityBadge`, `DeckBadge`: accent text on a 12% tint of itself) and as
  standalone label / border / icon colour (`sign_out_button`, the swatch
  selection ring, `course_selector`). Dark `text` variants are **lightened**
  from the light `text` hexes so they clear AA on the dark `mutedFill` badge
  ground.

| Key | Light `fill` | Dark `fill` | Light `text` | Dark `text` | Dark `text` on `#262624` |
|---|---|---|---|---|---|
| `slate` | `#CBD5E1` | `#7C8CA3` | `#64748B` | `#AEBBCC` | 7.8:1 |
| `red` | `#D06C60` | `#DA7C6F` | `#B0453A` | `#E88C80` | 6.1:1 |
| `amber` | `#D6C08B` | `#C9A961` | `#8A7534` | `#DCC078` | 8.5:1 |
| `green` | `#AFC3A8` | `#8FB183` | `#6E8A65` | `#A9C79E` | 7.4:1 |
| `teal` | `#8FC4BE` | `#5FA69D` | `#3F7A73` | `#82C6BD` | 7.5:1 |
| `blue` | `#9DBDD2` | `#7FA8C4` | `#4E7B95` | `#A0C6DE` | 7.9:1 |
| `violet` | `#B8AED9` | `#9C8FD1` | `#6D5FA8` | `#C0B4E8` | 7.9:1 |
| `pink` | `#E3AEBE` | `#CE8098` | `#B15C74` | `#E3A7BC` | 7.5:1 |

### 3.1 The fixed "Mastered" red

`RatingRow` fills the "Mastered" button with `accent('red').fill` regardless of
the deck's own accent, so the action is one recognisable signal everywhere
(v1 §6.2). In dark mode the button's label is `cardFill` (`#1E1E1E`), so the red
fill is nudged one shade lighter — `#D06C60` → **`#DA7C6F`** — purely to lift
dark-label contrast to **5.6:1** (≥ AA for the 15px semibold label). The hue is
unchanged to the eye; it is still unmistakably the same terracotta red, and the
same `#DA7C6F` circle carries the nav-bar Create button (dark `+` icon, 5.6:1).

### 3.2 Tints

Accent `fill` at 30–45% opacity over `#1E1E1E` / `#121212` produces a low-key
wash — exactly the muted register the light theme gets over white. No contrast
floor applies to a decorative tint; the dark `fill` values were chosen so the
hue survives the opacity knock-down rather than washing to grey.

---

## 4. Theme-mode selector

A three-way choice, **default System**:

| Option | Behaviour |
|---|---|
| **System** | Follow the OS light/dark setting live. `ThemeMode.system`. |
| **Light** | Force `AppTheme.light` regardless of the OS. |
| **Dark** | Force `AppTheme.dark` regardless of the OS. |

- Stored in `SharedPreferences` under key **`theme_mode`** as `ThemeMode.name`
  (`system` / `light` / `dark`). An unrecognised or absent value falls back to
  `system`.
- Surfaced in Settings as a new **"Appearance"** section placed directly above
  "Study appearance", using the existing `SettingsSegmentedControl<ThemeMode>`
  (System / Light / Dark).
- The write is optimistic with rollback on failure, matching
  `StudyAppearanceController` and `NotificationsEnabledController`.

### 4.1 Cold-start flash prevention

`MaterialApp` defaults to `ThemeMode.system` until the async preference read
resolves, which can flash the wrong theme for one or more frames on a device
whose OS and saved override disagree. To prevent this, `main()` **eagerly**
reads `theme_mode` from `SharedPreferences` before `runApp` (the same pattern as
`NotificationPreferences` for the reminders gate) and seeds it into the provider
via a `ProviderScope` override, so the very first frame already paints in the
saved theme.

The provider is an `AsyncNotifierProvider<ThemeModeController, ThemeMode>`. When
the seed override is present its `build()` returns the seeded value
synchronously (first frame is `AsyncData`); when it is absent (tests, or any
entrypoint that skips the eager read) `build()` falls back to reading the
preference asynchronously and, on any storage error, to `ThemeMode.system`.

---

## 5. System chrome (status bar & navigation bar)

The app has no `AppBar`, so `AppBarTheme.systemOverlayStyle` never fires. The
overlay style is instead applied app-wide via an
`AnnotatedRegion<SystemUiOverlayStyle>` in `MaterialApp.router`'s `builder`,
keyed off the resolved `Theme.of(context).brightness` so it tracks System, Light
and Dark automatically.

| | Light theme | Dark theme |
|---|---|---|
| Status-bar background | transparent | transparent |
| Status-bar icons (Android `statusBarIconBrightness`) | `Brightness.dark` (dark glyphs) | `Brightness.light` (light glyphs) |
| Status-bar brightness (iOS `statusBarBrightness`) | `Brightness.light` | `Brightness.dark` |
| Nav-bar background (`systemNavigationBarColor`) | `#FFFFFF` (`background`) | `#121212` (`background`) |
| Nav-bar icons (`systemNavigationBarIconBrightness`) | `Brightness.dark` | `Brightness.light` |
| Nav-bar divider | transparent | transparent |

---

## 6. Codebase audit — hardcoded colour stragglers

The ~67 `Theme.of(context).extension<AppTokens>()!` call sites adapt for free.
The following literals had slipped past the "only `app_tokens.dart`" rule and
are routed through tokens as part of this milestone:

| Site | Was | Now |
|---|---|---|
| `stacked_deck.dart` `_layer1` | `Color(0xFFEEF1F5)` | `tokens.borderHairline` (the darker, furthest-back layer) |
| `stacked_deck.dart` `_layer2` | `Color(0xFFF5F7FA)` | `tokens.mutedFill` (the lighter layer, nearer the card) |

Deliberately **left as-is**:

- `cloze_type_card.dart` `Colors.transparent` — a non-colour; theme-independent.
- `feynman_reference_dialog.dart` `barrierColor: Colors.black54` — a modal
  scrim. A translucent-black barrier is correct under both themes (it is
  Flutter's own default `barrierColor`); a light scrim over dark content would
  read as a flash.

`glass_bottom_nav_bar.dart` already composes its glass from
`tokens.cardFill.withValues(alpha: …)` and `tokens.textPrimary.withValues(alpha:
0.1)`, so it re-tints automatically. The one adjustment: the fill opacity is
raised from `0.55` to `0.72` under `Brightness.dark`, because a 55% veil of
`#1E1E1E` over already-dark scrolling content does not read as a distinct
surface — the higher opacity restores the "floating pill" separation the light
theme gets at 55% over white.

---

## 7. Test coverage

- `theme_mode_preference_test.dart` — round-trips each `ThemeMode`, defaults to
  `system` when unset, falls back to `system` on an unrecognised stored string.
- `theme_mode_provider_test.dart` — the seed override makes `build()` resolve
  synchronously to the seeded mode; without it the provider reads the
  preference; a write updates state and persists; a fresh build reads it back.
- `app_theme_dark_test.dart` — `AppTokens.dark` resolves from `AppTheme.dark`
  without throwing and carries the spec hexes; a widget forced to
  `Brightness.dark` via `MediaQuery` + `themeMode: ThemeMode.system` picks up
  `AppTokens.dark` fields; `themeModeProvider` set to `dark` drives
  `MaterialApp.themeMode`.
- Existing `app_tokens_test.dart` and settings tests stay green unchanged.
