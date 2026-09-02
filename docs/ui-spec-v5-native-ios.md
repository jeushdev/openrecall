# UI Spec v5 — Native iOS

Status: **active**. This spec **supersedes** the visual-identity layer of the
earlier UI specs and is the source of truth for typography, colour, surfaces,
elevation, motion, and the shell chrome:

- `ui-spec-v1.md` §3 (visual identity: the serif/sans pairing, the 0.5px
  hairline system, the **no-`BoxShadow` rule**, the glass nav pill) — **superseded**.
- `ui-spec-v3-design-language.md` §1 (typography: Fraunces + Inter) and §4
  (component themes built on the no-shadow rule) — **superseded**.
- `ui-spec-v2.md` (screen structure) and `ui-spec-v4-navigation.md` (the four-tab
  IA, `/settings` outside the shell) — **still hold**. v5 changes how the shell
  and its screens *look*, not which screens exist or how they are routed.
- `docs/spec-v5-dark-mode.md` — the System/Light/Dark selector mechanism holds;
  the dark **palette values** in it are replaced by §3 below.

## Why this exists

The v1–v3 design language is a deliberate editorial system: Fraunces serif +
Inter, flat white, 0.5px hairlines, no shadows, a floating glass nav pill. It is
internally consistent and well built. The owner's decision, September 2026, is
that it does not read as a modern native mobile app and should be replaced with a
**native-iOS aesthetic** in the spirit of the Gizmo and Tarsi study apps: a
system-style typeface, iOS grouped surfaces with soft elevation, standard iOS
navigation chrome, a vibrant tint colour, and larger, friendlier type.

This is a **re-skin, not a re-architecture**. No screen is added or removed. No
navigation flow changes. Riverpod, go_router, the `StatefulShellRoute` shell, the
`AppTokens` `ThemeExtension` plumbing, and every feature's
presentation/domain/data split are untouched. What changes is the token values,
the type scale, the component themes, the route transition, the bottom nav
widget, and a set of targeted per-screen passes that adopt the new grouped-list
and large-title patterns.

The "earned moments only" stance from `spec.md` still holds in full: no XP,
badges, levels, streak-currency, confetti, or daily goals. Native-iOS here means
*polish and familiarity*, not gamification.

## Non-goals

- No information-architecture changes. Same four tabs, same screen inventory,
  same deck/session/study flows.
- No new features. Editable username and user-uploaded profile pictures are a
  **separate follow-up milestone** and are out of scope here.
- No iOS build. The app stays Android-only this phase; "native iOS" is a visual
  target achieved with Material widgets, not a `CupertinoApp` migration.
- No real Cupertino widget adoption (`CupertinoListSection`,
  `CupertinoNavigationBar`, `CupertinoSwitch`, …). The look is rebuilt on themed
  Material widgets and a small set of custom widgets so the existing screens and
  their widget tests keep working.
- No custom squircle (continuous-corner) painter. Standard `BorderRadius.circular`
  corners. Revisit only if it is cheap and the difference is visible.

## 1. Typography

Fraunces (the serif) is **removed** from the app, its assets and its
`pubspec.yaml` font entry deleted. Two families remain, both bundled as variable
TTFs under `assets/fonts/` with their OFL licence text registered via
`LicenseRegistry` in `main()` — never `google_fonts`, because the app reads its
theme before `runApp` and must work offline (`ui-spec-v3` §1 rationale, still
valid).

| Role | Family | Notes |
| --- | --- | --- |
| Display / character | **Figtree** | Open-licensed (OFL) variable geometric sans with softened terminals. Carries the greeting, large titles, screen titles, section headers, and big numbers — the "friendly" voice. |
| UI / content | **Inter** | Already bundled. Body text, list rows, buttons, captions, form fields, and — with `FontFeature.tabularFigures()` — every changing number. |

Figtree's variable TTF (`Figtree.ttf`, upright only — the app uses no italic
display text) and `Figtree-OFL.txt` are added to `assets/fonts/`. If a fetch of
the upstream file is needed at build time it comes from the `google/fonts` GitHub
repo; it is then committed to the repo like the Inter files.

### The scale — `lib/theme/app_type.dart`, `AppType`

Sizes follow the iOS type ramp. Body text moves from 14–15 to **17** — this is
the single most load-bearing change for "feels native".

| Token | Family / size / weight / tracking | Used for |
| --- | --- | --- |
| `largeTitle` | Figtree 34 / w700 / -0.4 | Collapsing large nav titles; the Home greeting |
| `title1` | Figtree 26 / w700 / -0.3 | Screen titles without a large-title header |
| `title2` | Figtree 22 / w600 | Section headers, card titles |
| `title3` | Figtree 20 / w600 | Sub-section headings |
| `headline` | Inter 17 / w600 | Emphasised body; list-row titles |
| `body` | Inter 17 / w400 / height 1.4 | Primary text; flip-card front & back; Feynman prompt |
| `callout` | Inter 16 / w400 | Slightly reduced body in dense contexts |
| `subhead` | Inter 15 / w400 | Secondary text |
| `footnote` | Inter 13 / w400 | Metadata, the study counter |
| `caption` | Inter 12 / w400 | Smallest metadata; grouped-list section footers |
| `overline` | Inter 11 / w700 / +0.8 / uppercase | The `PROMPT` / `ANSWER` kickers (unchanged role) |
| `numeric` | Inter 17 / w600 / tabular | Any changing number inline with body |
| `numericLarge` | Inter 28 / w700 / tabular | Session-summary metric values, count-ups |
| `displayNumber` | Figtree 40 / w700 / tabular | The one big number — the session-summary mastery percentage |

The `cardBody` role from v3 is merged into `body` (both are now Inter 17). The
v3 `display` serif role becomes `displayNumber`.

`AppType.textTheme(AppTokens)` maps these onto the Material `TextTheme` slots so
un-styled Material widgets inherit them. Figtree lands on `display*`,
`headline*`, and `titleLarge`; Inter lands on everything else.

## 2. Motion — `lib/theme/app_motion.dart`, `AppMotion`

The v3 vocabulary is kept and extended rather than replaced.

| Token | Duration | For |
| --- | --- | --- |
| `instant` | 90ms | Press-in / press-release on buttons and rows |
| `fast` | 140ms | Cross-fades, small state flips |
| `base` | 220ms | Card-to-card advance, most transitions |
| `expand` | 260ms | Disclosure expand/collapse; grouped-list row insert |
| `page` | 350ms | Route push/pop (matches `CupertinoPageTransition`) |
| `slow` | 520ms | The session-summary reveal — count-ups and the mastery arc |

Curves: `standard` (`Curves.easeOutCubic`), `decelerate` (`Curves.easeOut`),
`spring` (`Curves.easeOutBack`, tuned — the small overshoot that reads as iOS
"weight": a card settling after a flip, a rating button releasing, a row
press-release).

**Rule, unchanged from v1/v3:** motion never gates state. Every animation in the
study loop is cosmetic; the queue advances, the rating records, and the progress
bar updates synchronously regardless of animation status.

## 3. Colour & surfaces — `lib/theme/app_tokens.dart`, `AppTokens`

`AppTokens` gains one field, **`tint`** (the interactive/accent colour, new to
v5). Every other field keeps its name; only the values change. `AppTokens.light`
and `AppTokens.dark` stay the only place raw colour literals are allowed.

### Neutral ramp

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `background` | `#F2F2F7` | `#000000` | Screen background — iOS grouped background |
| `cardFill` | `#FFFFFF` | `#1C1C1E` | Elevated surfaces: cards, list sections, sheets, nav bars |
| `mutedFill` | `#EFEFF4` | `#2C2C2E` | Inset fills: form fields, inactive segmented-control track, stat blocks |
| `borderHairline` | `#C6C6C8` | `#38383A` | Separators and 1px control borders (renamed role kept; it is the iOS separator colour now, not a 0.5px hairline) |
| `textPrimary` | `#1C1C1E` | `#FFFFFF` | Labels, headings |
| `textSecondary` | `#8E8E93` | `#98989F` | Secondary labels, captions, metadata |
| `textTertiary` | `#C7C7CC` | `#48484A` | Placeholder, disabled |
| `tint` | `#007AFF` | `#0A84FF` | **New.** Primary buttons, interactive text, selected tab, switches-on-alt, focus ring |

Separator width becomes **1px** (`AppBorders.hairline` renamed conceptually; the
constant is set to `1.0`). The v1 0.5px hairline system is retired — iOS uses 1px
(≈0.33pt physical) separators and no border on cards.

### Elevation — `lib/theme/app_geometry.dart`, `AppShadows` (new)

The app-wide `BoxShadow` ban is **lifted**. Elevation is now a small, fixed set
of soft shadows, never a Material `elevation:` int.

| Token | Light | Dark |
| --- | --- | --- |
| `card` | `BoxShadow(color: #000 @ 6%, blur 12, offset (0, 3))` | none — dark separation is carried by `cardFill` vs `background` contrast |
| `raised` | `BoxShadow(color: #000 @ 10%, blur 20, offset (0, 6))` | `BoxShadow(color: #000 @ 40%, blur 20, offset (0, 6))` — sheets, the nav bar's top edge glow is a hairline, not this |

Cards in light mode carry `card` and **no border**. In dark mode they carry no
shadow and no border — the fill contrast is the separation.

### Radii — `lib/theme/app_geometry.dart`, `AppRadii`

| Token | Value | Used for |
| --- | --- | --- |
| `card` | 20 | Cards, study surfaces, sheets (top corners), dialogs |
| `tile` | 16 | Deck grid tiles |
| `section` | 12 | Grouped-list section containers |
| `control` | 12 | Form fields, segmented controls, small chips |
| `button` | 14 | Filled / outlined / text buttons |

### Accents — the eight `AccentPair`s

The eight keys (`slate`, `red`, `amber`, `green`, `teal`, `blue`, `violet`,
`pink`) are **kept** so `courses.accent_color` values and all course-accent code
keep working. Their values are re-tuned to the nearest iOS system colour, each
still an `AccentPair(fill, text)` where `fill` is used at 30–45% opacity for
tints and `text` is the full-strength label colour, contrast-checked (WCAG AA)
against a `mutedFill` badge ground in both themes.

| Key | Light `text` (approx iOS system colour) |
| --- | --- |
| `slate` | `#8E8E93` systemGray |
| `red` | `#FF3B30` systemRed |
| `amber` | `#FF9500` systemOrange |
| `green` | `#34C759` systemGreen |
| `teal` | `#30B0C7` systemTeal |
| `blue` | `#007AFF` systemBlue |
| `violet` | `#5856D6` systemIndigo |
| `pink` | `#FF2D55` systemPink |

Exact `fill` values, the dark-theme values, and the contrast table are filled in
during implementation the same way `spec-v5-dark-mode.md` did it. `red` remains
the fixed "Mastered" rating colour.

## 4. Component themes — `lib/theme/app_theme.dart`, `AppTheme._build`

Every value routes through `AppTokens` / `AppRadii` / `AppShadows`. Component
themes updated:

- **`cardTheme`** — `cardFill`, `AppRadii.card`, no border, `AppShadows.card` in
  light (applied via a wrapping `DecoratedBox`/`Material` where `CardTheme`
  cannot express a `BoxShadow` — a small `AppCard` widget owns this).
- **`filledButtonTheme`** — background `tint`, foreground white, `AppRadii.button`,
  min height 50, label Inter 17 / w600, pressed state = 0.85 opacity. The v1/v3
  near-ink primary button is retired.
- **`textButtonTheme`** — foreground `tint`, label Inter 17.
- **`outlinedButtonTheme`** — foreground `textPrimary`, 1px `borderHairline`
  side, `AppRadii.button`.
- **`inputDecorationTheme`** — filled `mutedFill`, `AppRadii.control`, **no
  border** in the resting/enabled state (iOS style), a 1px `tint` border on
  focus, `errorStyle` in `accent('red').text`.
- **`dialogTheme`** — `cardFill`, `AppRadii.card`, `AppShadows.raised`, no border.
- **`bottomSheetTheme`** — `cardFill`, `AppRadii.card` top corners,
  `AppShadows.raised`, drag handle in `textTertiary`.
- **`switchTheme`** — track `#34C759` systemGreen when on, `mutedFill` when off,
  white thumb, no track outline. (This is the one place a non-`tint` accent is
  correct — iOS switches are green.)
- **`dividerTheme`** — `borderHairline`, thickness 1.
- **`snackBarTheme`** — dark floating pill (`textPrimary` bg, `background`
  label), `AppRadii.control`.
- **`listTileTheme`** — used only outside grouped lists; title Inter 17,
  subtitle `subhead` in `textSecondary`.
- **`segmentedButtonTheme`** — `mutedFill` track, `cardFill` selected thumb with
  `AppShadows.card`, `AppRadii.control`, label Inter 15.
- **`progressIndicatorTheme`** — `tint` fill, `borderHairline` track.
- **`appBarTheme`** — transparent, no elevation, no scrolled-under tint; large
  title styling is owned by the `LargeTitleScaffold` helper (§5), not here.
- **`ColorScheme`** — `primary`/`onPrimary` become `tint`/white; `surface*`,
  `outline*`, `onSurface*`, `error` stay pinned to tokens so a widget reaching
  past the component theme still lands on-palette.

## 5. Shell chrome & shared widgets

### 5.1 Bottom navigation — replaces `GlassBottomNavBar`

`GlassBottomNavBar` (the floating glass pill) is replaced by `IosTabBar`: a
**full-width** bar in the `Scaffold.bottomNavigationBar` slot, `cardFill` at ~92%
opacity over a `BackdropFilter` blur, a 1px `borderHairline` top edge, safe-area
aware. Four items (Home, Decks, History, More), each an icon above a 10pt Inter
label; selected item in `tint`, unselected in `textSecondary`. No background
highlight, no pill.

The central **Create (+)** button leaves the tab bar. Create is invoked from a
trailing `+` button in the large-title header of **Home** and **Decks** (it opens
the existing `create_menu_sheet`). This is the standard iOS pattern and removes
the non-native centre-FAB.

`ScaffoldWithNavBar` keeps its branch-slide transition and its `Offstage` stack
(state preservation) exactly as today — only the `bottomNavigationBar:` widget
changes. `extendBody` stays `true` so content scrolls under the blur.

### 5.2 Large-title headers — `LargeTitleScaffold`

A reusable widget wrapping `CustomScrollView` + a `SliverAppBar` that shows the
screen title in `AppType.largeTitle`, collapsing to a centred `AppType.headline`
inline title on scroll, with an optional list of trailing action buttons. Used
by **Home, Decks, History, More**. `Settings` (pushed, outside the shell) uses
the same widget with a back chevron leading item.

### 5.3 Grouped-inset lists — `IosSection` / `IosRow`

Two small widgets implementing the iOS Settings look:

- **`IosSection`** — an optional uppercase `caption` header in `textSecondary`,
  a `cardFill` container with `AppRadii.section` corners and (light) `AppShadows.card`,
  an optional `caption` footer below it, and standard 16pt horizontal inset from
  the screen edge.
- **`IosRow`** — a 44pt-min-height row: optional leading icon in a 28pt
  rounded-rect badge tinted with an `AccentPair.fill`, a `body` (Inter 17) title,
  an optional trailing value in `textSecondary` and/or a chevron
  (`textTertiary`), a full-width-minus-leading-inset 1px separator between rows
  (never after the last). Tappable rows get an `instant`/`spring` press
  highlight (`mutedFill` overlay).

**More** and **Settings** are rebuilt on these. The current `_Group` / `_NavRow`
/ `_StatusRow` / `_RowDivider` private widgets in `more_tab_screen.dart` and the
equivalents in the settings screen are deleted in favour of them.

### 5.4 Route transitions

The router's page builder switches from the default (`MaterialPage`) to
`CupertinoPage` for every route, giving the horizontal slide and the
edge-swipe-back gesture. The shell branch routes keep their existing in-shell
slide (§5.1). No change to route paths, guards, or `StatefulShellRoute`
structure.

### 5.5 System overlay

`AppTheme.lightOverlay` / `darkOverlay` update: light nav-bar colour
`#F2F2F7`, dark `#000000`, to match the new `background`.

## 6. Screen passes

Done in this order. Passes 2–7 are mostly "verify the inherited theme looks
right and adopt the new shared widgets"; only 6 is a structural rebuild.

1. **Foundation** — everything in §1–§5: tokens (+`tint`), type scale (+Figtree
   asset, −Fraunces), `AppShadows`, `AppRadii`, motion tokens, all component
   themes, `CupertinoPage`, `IosTabBar`, `LargeTitleScaffold`, `IosSection` /
   `IosRow`, overlay colours. After this pass every screen already looks new.
2. **Home** — `LargeTitleScaffold` with the greeting as the large title (this
   removes the serif `_GreetingHeader` and resolves the "greeting font looks
   bad" complaint), a trailing `+`, restyled section headers
   (`AppType.title2`), the unfinished-sessions strip and the Overall Mastery
   card on `AppCard`.
3. **Decks** — grid tiles on `AppRadii.tile` + `AppShadows.card`, the
   `LargeTitleScaffold` header with a trailing `+`; deck-detail header and
   content hierarchy verified.
4. **Study loop + Session Summary** — surfaces, buttons, and type inherit; keep
   the flip-weight / rating press-in / progress-bar behaviour from v3 §5. The
   session-summary mastery arc keeps its shape; its centre number moves to
   `AppType.displayNumber`, metric values to `AppType.numericLarge`. The literal
   strings the widget tests assert ("This session", "Drill parked cards now",
   "Done", the mastery-delta label) are unchanged.
5. **History** — calendar heatmap cells re-mapped to `tint` opacity steps (or a
   single `AccentPair` ramp), session-log rows as `IosRow`s inside `IosSection`s
   grouped by date.
6. **More + Settings** — full rebuild on `IosSection` / `IosRow`. The More
   profile block becomes a large tappable row (avatar + name + a "Account"
   disclosure) that pushes `/settings`. Settings sections (Notifications, Study
   preferences, Appearance/theme, Data/offline-sync, About, Delete account)
   become grouped sections. Delete account stays a destructive `red` row inside
   Settings only — never duplicated.
7. **Auth + splash** — inherit the theme; the primary CTA becomes the new tinted
   `filledButton`; the splash logo lockup verified against the new `background`.

## 7. Testing & verification

- `flutter analyze` — clean, required before commit.
- `flutter test` — green. Widget tests that assert on removed things (the
  `Fraunces` family, `GlassBottomNavBar`, the old hex palette, the centre-FAB
  Create button, the near-ink primary button) are **updated to the v5
  equivalents**, not deleted or skipped. Watch the session-summary and
  flip-card tests (count-ups stay finite `TweenAnimationBuilder`s so
  `pumpAndSettle` settles) and any golden tests (regenerate).
- `flutter run` on the Android emulator — a visual pass per screen: the large
  titles collapse correctly, the tab bar blur reads, the grouped lists on
  More/Settings match iOS Settings, the study loop is unbroken, dark mode is
  correct on every screen, and there is no seeded-Material grey leak.

## 8. Follow-up (not this milestone)

Editable username and user-uploaded profile pictures: add a `username` (and
`avatar_url`) column to `profiles`, a Supabase Storage `avatars` bucket with
owner-scoped RLS, an `image_picker` dependency, an edit screen pushed from the
More profile row, and a client-side downscale/compress before upload. Scoped and
built in its own session on top of v5.
