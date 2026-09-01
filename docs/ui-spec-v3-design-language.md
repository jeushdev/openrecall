# UI Spec v3 — Design Language

Status: **active**. Supersedes nothing wholesale — it *completes* `ui-spec-v1.md`
§3 (visual identity) and adds the two layers v1 and v2 never named: **typography**
and **motion**. `ui-spec-v2.md` (presentation-layer revamp) still holds for
screen structure.

## Why this exists

The design system in `ui-spec-v1.md` is good and locked — eight WCAG-checked
`AccentPair`s, a 28/16/12 radius scale, 0.5px hairlines, a no-`BoxShadow` rule,
the glass nav pill, the stacked-deck depth trick. The problem is that it is only
**half-installed**:

1. **There is no typography.** Every screen builds `TextStyle(fontSize: …)` inline
   — roughly 186 of them. There is no type scale, no font, nothing that makes an
   ActiveRecall screen recognisable as ActiveRecall rather than as default
   Material.
2. **~40% of the app renders on raw seeded Material 3.** `AppTheme._build` sets a
   `ColorScheme.fromSeed` and *no component themes*, so every un-tokened
   `AppBar`, `Card`, `FilledButton`, `Dialog`, `Switch`, `SnackBar` and
   `BottomSheet` paints in M3's seeded grey — most visibly the Session Summary,
   which is 100% stock.
3. **Motion has no language.** `AppMotion` names exactly one duration/curve pair.
   Everything else is an inline `Duration(milliseconds: …)` literal. Haptics are
   three scattered `HapticFeedback.selectionClick()` calls.

This spec fills those three gaps. It adds **zero** new screens and **zero**
gamification (see the "earned moments only" stance in `spec.md`): no XP, badges,
levels, streak-currency, confetti, or daily goals. The reward is that the moments
the user has already earned — a card flip, a rating landing, a session finishing
— are given real weight.

## 1. Typography

**Pairing: editorial serif + sans.**

| Role | Family | Notes |
| --- | --- | --- |
| Character / content | **Fraunces** | Open-licensed variable serif, optical-size + soft + wonk axes. Carries headings, big numbers, and card content. |
| UI chrome | **Inter** | Variable sans with tabular figures. Runs tabs, badges, buttons, captions, settings rows, stat values. |

**Delivery: bundled as assets, never `google_fonts`.** The app is offline-first
and reads its theme *before* `runApp` to avoid a theme flash (`main.dart`). A
runtime font fetch would reintroduce exactly that flash and fail offline. The
variable TTFs live in `assets/fonts/` with their OFL license text, registered
with `LicenseRegistry` in `main()`. Flutter maps `FontWeight` onto the `wght`
axis automatically; the `opsz` axis is left at its default instance except on the
display styles, which pin it via `fontVariations`.

**The scale** (`lib/theme/app_type.dart`, `AppType`):

| Token | Family / size / weight | Used for |
| --- | --- | --- |
| `display` | Fraunces 40 / w600, opsz 40 | Session-summary mastery number |
| `headline` | Fraunces 26 / w600 | Screen titles |
| `title` | Fraunces 20 / w600 | Card titles, section headers, summary card headings |
| `cardBody` | Fraunces 20 / w400 / height 1.4 | Flip card front & back, Feynman prompt |
| `bodyLarge` | Inter 15 / w400 | Primary UI text, metric labels |
| `body` | Inter 14 / w400 | Secondary UI text |
| `label` | Inter 13 / w600 | Buttons, badges, rating-row labels |
| `caption` | Inter 12 / w400 | Metadata, the study counter |
| `overline` | Inter 11 / w700 / +0.8 tracking / uppercase | The `PROMPT` / `ANSWER` kickers |
| `numeric` | Inter, tabular figures | Any changing number (stat tiles, counts) |

`AppType.textTheme(AppTokens)` maps these onto the Material `TextTheme` slots so
un-styled Material widgets inherit them; the serif-only and tabular styles are
also exposed as static getters for direct use.

## 2. Motion

`lib/theme/app_motion.dart`, `AppMotion` — one vocabulary, five durations:

| Token | Duration | For |
| --- | --- | --- |
| `instant` | 90ms | Press-in / press-release on buttons |
| `fast` | 140ms | Cross-fades, small state flips |
| `base` | 220ms | Card-to-card advance, most transitions |
| `expand` | 240ms | Disclosure expand/collapse (unchanged from v1) |
| `slow` | 520ms | The session-summary reveal — count-ups and the mastery arc |

Curves: `standard` (`Curves.easeOutCubic`), `decelerate` (`Curves.easeOut`),
`emphasized` (`Curves.easeOutBack`, used only where a small overshoot reads as
"weight" — the card settling after a flip, the rating button releasing).

**Rule:** motion never gates state. Every animation in the study loop is
cosmetic; the queue advances, the rating records, and the progress bar updates
synchronously regardless of animation status (`ui-spec-v1.md` §2).

## 3. Haptics

`lib/theme/app_haptics.dart`, `AppHaptics` — a named vocabulary over
`HapticFeedback`, each call wrapped so a platform-channel failure is swallowed:

| Call | Feedback | Fires on |
| --- | --- | --- |
| `AppHaptics.tap()` | `selectionClick` | Card flip, generic selection |
| `AppHaptics.rating()` | `lightImpact` | A rating button commit |
| `AppHaptics.commit()` | `mediumImpact` | A card leaving the queue for good (mastered/parked) |
| `AppHaptics.sessionComplete()` | `mediumImpact` then, after 60ms, `lightImpact` | The Session Summary appearing |

## 4. Component themes

`AppTheme._build` gains a `textTheme` and component themes so nothing falls back
to seeded M3. All values route through `AppTokens` / `AppRadii` / `AppBorders`;
**no `BoxShadow`**, so every button/card/dialog elevation is `0` and depth stays
faked with borders and offset fills.

Themed: `AppBarTheme`, `FilledButtonThemeData`, `TextButtonThemeData`,
`OutlinedButtonThemeData`, `InputDecorationTheme`, `CardThemeData`,
`DialogThemeData`, `BottomSheetThemeData`, `SwitchThemeData`, `DividerThemeData`,
`SnackBarThemeData`, `ListTileThemeData`, `SegmentedButtonThemeData`,
`ProgressIndicatorThemeData`. The `ColorScheme` also gets its `surface*`,
`outline*`, `primary`, `onSurface*` and `error` slots pinned to tokens so a
widget reaching past the component theme still lands on-palette.

## 5. Study-loop moments (Phase 2)

The foundation above is invisible. These are where the user feels it.

### 5.1 Flip card

The face text moves to `AppType.cardBody` / `AppType.overline`. The 3D flip gains
**weight**: the card scales to ~0.96 at the mid-turn and eases back to 1.0 on an
`emphasized` curve, so the flip has a small physical settle instead of a flat
rotation. `AppHaptics.tap()` on the flip. The `fade` transition option is
untouched.

### 5.2 Rating row

Each button gets a press-in: `scale` to 0.96 and fill darkening on tap-down,
release on an `emphasized` curve (`AppMotion.instant`). `AppHaptics.rating()` on
commit. "Mastered" keeps its fixed `red` accent. The existing directional
card-exit (`_exitFor`) is kept; `AppHaptics.commit()` is added when the verdict
is 0 or 4 (the card leaves the queue).

### 5.3 Progress bar

Thickens from 2px to 3px with a rounded right cap on the fill. The ease uses
`AppMotion.base` / `AppMotion.decelerate`. Still label-less.

### 5.4 Session Summary — the designed moment

Full rebuild of `session_summary_view.dart`. Removes the stock `AppBar` and
`scheme.primaryContainer`. New structure on a token background:

- A centred **mastery arc**: a custom-painted arc (no shadow, hairline track,
  `blue`-accent progress) with the deck's *after* percentage in `AppType.display`
  at its centre. On first build it animates the arc and counts the number from
  *before* → *after* over `AppMotion.slow` on `decelerate`. `masteryDeltaLabel`
  sits under it in `AppType.title`.
- A **"This session"** block (literal heading kept — a test asserts it) of metric
  rows: label in `AppType.bodyLarge`, value in `AppType.numeric`, each value
  counting up from 0 over `AppMotion.slow`.
- `AppHaptics.sessionComplete()` once, on first frame.
- Actions: the "Drill parked cards now" `FilledButton` when `hasParked`, then the
  `Done` `TextButton` (both literals kept — tests assert them). Styled by the new
  button themes.

Count-ups are finite `TweenAnimationBuilder`s — no `.repeat()` — so
`pumpAndSettle` in the widget tests still settles.

## 6. What Phase 2 deliberately leaves alone

Tabs, sheets, dialogs, auth, creator screens, stats, profile, settings. They
inherit the type scale and component themes for free and are not individually
redesigned this pass. Information architecture (home / deck-detail content
hierarchy) is explicitly **out of scope** — the user did not ask for it.

## 7. Verification

- `flutter analyze` clean.
- `flutter test` green (watch the summary/flip-card widget tests).
- `flutter run` visual pass: the study loop (flip weight, rating press, progress
  bar), the Session Summary moment, and a sample of inherited screens (a tab, a
  dialog, the settings list) to confirm the grey leak is gone.
