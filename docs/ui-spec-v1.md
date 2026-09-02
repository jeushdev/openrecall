# ActiveRecall — UI Revamp Spec (v1)

## 0. Status & relationship to other specs

This is the UI counterpart to `docs/spec.md` (V1 engine) and `Engine V2 spec`
(courses, `card_scope`, local aggregation). **Engine V2 milestones 15–17 are
confirmed complete** (commits `d187d45`, `06f76a1`, `e6ec97b`): `courses` table
+ `course_id` on `decks`, `study_sessions.card_scope`, and the local
aggregation providers (`overallMasteryProvider`, Troublemakers, per-deck
run-through count via `DeckSummary.masteryLevelSum`, `CourseSummary` rollups)
all exist in `lib/features/stats/`. `CourseRepository`'s write path
(create/update/delete) is **not** part of this — milestone 15's commit message
explicitly notes "read path only" — so §7's block on Course Creator still
applies as written.

This doc covers **presentation layer only** — routing, theming, screens, and
widget-level component specs. It does not add or change any schema, model, or
repository method beyond what Engine V2 already defines. Where a screen needs a
capability Engine V2 doesn't yet expose (see §7, Course Creator), that's called
out explicitly as blocked, not silently assumed.

---

## 1. Reconciliation notes — where earlier UI deliberation was wrong

Several decisions made before Engine V2 was reconciled against the real codebase
do not hold. Recorded here so the agent doesn't rebuild against the old (wrong)
assumptions if it sees them in chat history or old notes.

| Earlier assumption | Reality per Engine V2 | Reconciled UI decision |
|---|---|---|
| "Cram" is a fully separate, isolated session system that never touches long-term progress. | `card_scope: 'all'` is one flag on the *same* study loop. Cards still write `mastery_level` on every rating. A Mastered card rated below 4 during an "all" run **regresses** — this is correct, not a bug. | UI copy must never imply "all cards" mode is consequence-free or a rehearsal. See §6.1 for exact copy. |
| Exit-the-queue threshold for the new mode was "rating 2–4". | The loop's existing threshold is **rating ≥ 4 only** (true Mastered). Ratings 1–3 all requeue, same as V1. | Rating row behavior is identical between `due` and `all` scope — no threshold change. |
| Deck tile shows a `mastery_count` field, incremented client-side. | No such column exists or will exist — it's derived: `count(*) from study_sessions where card_scope='all' and status='completed'`. | UI reads this from the new per-deck run-through provider (§7), never from a `Deck.masteryCount` field. |
| Deck accent color is a free/curated hex chosen at Course-creation time. | `courses.accent_color` is a **named-key enum**: `slate, red, amber, green, teal, blue, violet, pink`. Hex mapping lives in the Flutter theme layer, not the database. | Color picker in Course Creator offers exactly these 8 keys (§4.4), never a hex/RGB input. |
| Sync must run mandatorily right before every session start, blocking-if-offline-then-proceed. | Engine V2's actual sync triggers are: connectivity returning, app resume, session exit/finish. No explicit "on session start" trigger is speced. | UI does **not** add a pre-session sync call. Rely on the existing triggers; if a session starts against slightly stale local data, that's accepted (matches the zero-network-blocking invariant more directly than forcing a sync call in the hot path). |
| "Study" and "Cram" are named as if they were different modes/screens. | It's one screen, one controller, one `CardScope` argument. | Renamed throughout this doc: the Decks-tab segmented control is **Due / All**, not Study / Cram. Internally this maps 1:1 to `CardScope.due` / `CardScope.all`. |

---

## 2. Core invariants (unchanged from engine, binding on UI too)

- **Zero-network invariant.** No tap, flip, rating, or reveal in a study session
  ever awaits a network call. All screens read from local/cached state.
- **Optimistic UI.** A rating is reflected in the UI (card retiring/requeuing,
  progress bar advancing) immediately, before any write confirms.
- **No blind color input.** Every accent color in the UI traces back to one of
  the 8 named `accent_color` keys — never a raw hex typed or picked freely by a
  user.
- **`CardScope.all` is a real study run.** Nothing in copy, iconography, or
  animation may suggest it's lower-stakes than a `due` run.

---

## 3. Visual identity & tokens

> **Superseded by `docs/ui-spec-v5-native-ios.md`** (typography, elevation, nav chrome).

### 3.1 Palette

> **Superseded (milestone UX6):** dark mode is now designed.
> `docs/spec-v5-dark-mode.md` is the source of truth for the dark palette, the
> System/Light/Dark selector, and the status-bar / nav-bar treatment. The table
> below is still the authoritative **light** palette; the dark counterparts live
> in that spec and in `AppTokens.dark`.

| Token | Hex | Usage |
|---|---|---|
| `surface.background` | `#FFFFFF` | Screen background |
| `surface.card` | `#FFFFFF` | Card/tile fill |
| `surface.mutedFill` | `#F7F7F5` | Stat blocks, inactive segmented-control track |
| `border.hairline` | `#EDEDED` | 0.5px card/tile borders |
| `text.primary` | `#1A1A1A` | Headings, primary labels |
| `text.secondary` | `#8A8A8A` | Captions, metadata |
| `text.tertiary` | `#B0B0B0` | Placeholder/disabled |

### 3.2 Accent key → hex mapping

Maps directly to the `courses.accent_color` check-constraint values. Each key
has a **fill** (used at 30–45% opacity for stacked-deck / left-shadow accents)
and a **text** variant (full-strength, pre-checked for contrast on
`surface.mutedFill`-tinted badges).

| Key | Fill hex | Text/badge hex |
|---|---|---|
| `slate` (default/uncategorized) | `#CBD5E1` | `#64748B` |
| `red` | `#D06C60` | `#B0453A` |
| `amber` | `#D6C08B` | `#8A7534` |
| `green` | `#AFC3A8` | `#6E8A65` |
| `teal` | `#8FC4BE` | `#3F7A73` |
| `blue` | `#9DBDD2` | `#4E7B95` |
| `violet` | `#B8AED9` | `#6D5FA8` |
| `pink` | `#E3AEBE` | `#B15C74` |

No other colors are introduced anywhere in the app. If a screen needs a status
color (e.g., "low" troublemaker severity badge), reuse `red`'s text/fill pair
rather than adding a new hue.

### 3.3 Geometry

- Card/tile corner radius: `28.0` (`BorderRadius.circular(28)`), `16.0` for
  grid deck tiles specifically (smaller surface, tighter radius reads better —
  confirm visually once built; not a hard rule).
- Borders: `0.5px`, `border.hairline`, on every card/tile/nav surface.
- No `BoxShadow` anywhere. All "depth" (stacked-deck effect, left-accent shadow)
  is built from solid offset `Container`s at reduced opacity — see §5.2 and
  §6.4. This is a hard constraint, not a preference: `BoxShadow`/blur on
  frequently-rebuilt widgets (the study card) risks frame drops on mid-range
  Android devices, which conflicts with the zero-network/optimistic-UI
  invariant's spirit of a consistently responsive study loop.

### 3.4 Token delivery

`ThemeExtension<AppTokens>` registered on the app's single (light) `ThemeData`.

```dart
class AppTokens extends ThemeExtension<AppTokens> {
  final Color background, cardFill, mutedFill, borderHairline;
  final Color textPrimary, textSecondary, textTertiary;
  final Map<String, AccentPair> accents; // keyed by the 8 named accent_color values
  ...
}

class AccentPair {
  final Color fill;
  final Color text;
  const AccentPair(this.fill, this.text);
}
```

Access via `Theme.of(context).extension<AppTokens>()!`. Resolve a course's
accent with `tokens.accents[course.accentColor]!` — never hardcode a hex
literal outside `AppTokens`'s construction.

---

## 4. Routing (`lib/routing/`)

`go_router`, `StatefulShellRoute.indexedStack` for the four tabs; everything
else is a top-level route outside the shell.

```
/                              → redirect to /decks
StatefulShellRoute (indexedStack, state preserved per branch)
  branch: /decks               → DecksTabScreen
  branch: /mastery              → MasteryTabScreen
  branch: /profile              → ProfileTabScreen
  branch: /settings             → SettingsTabScreen

Outside the shell (top-level, no bottom bar):
  /study/:deckId?scope=due|all  → StudySessionScreen
  /deck-creator                 → DeckCreatorScreen
  /course-creator                → CourseCreatorScreen   (blocked, see §7)
```

- Query param `scope` on `/study/:deckId` maps directly to `CardScope`;
  defaults to `due` if absent.
- The shell's bottom nav bar is a widget conditionally rendered by the
  `StatefulShellRoute`'s scaffold — it is simply never part of the widget tree
  for the three top-level routes above, not hidden via opacity/visibility.
- Center **Create** action pushes `/deck-creator` (a full top-level route, not
  a shell branch) so back-navigation returns to whichever tab launched it.

---

## 5. Shell chrome

### 5.1 Bottom navigation bar

- Floating, rounded pill: `left: 16, right: 16, bottom: 18 + MediaQuery.viewPadding.bottom`
  (safe-area aware — required for gesture-nav Android/notched iPhones).
- Height `66`, `borderRadius: 28`, background `rgba(255,255,255,0.55)` +
  `BackdropFilter(ImageFilter.blur(sigmaX: 16, sigmaY: 16))`.
- Border: `0.5px`, `rgba(26,26,26,0.1)` — **not** `borderHairline` at full
  opacity; the glass surface needs a darker-tinted, low-opacity border to stay
  visible against light content scrolling underneath it (a plain
  `border.hairline` white-on-white border disappears under blur — confirmed
  via mockup iteration, don't regress this).
- Tabs: Decks, Mastery, [Create], Profile, Settings. Create is not a
  `NavigationDestination` — it's a separate `GestureDetector`/`InkWell`
  positioned in the same row, `48×48`, filled `red` accent (`#D06C60`),
  circular, centered icon `Icons.add` (or equivalent), sitting inline at the
  same height as the tab icons (not elevated above the bar — this was
  explicitly chosen over a floating/elevated variant).
- Active tab icon/label color: `text.primary`. Inactive: `text.tertiary`.
  Selection state is conveyed by color only, no background pill/highlight
  behind the icon.
- **Performance note:** the `BackdropFilter` here is acceptable because this
  bar is never mounted during a Study session (§4) — the expensive blur never
  competes with the zero-network-blocking study loop for frame budget.

---

## 6. Screens

### 6.1 Decks tab (`/decks`)

- Header "Decks", then a segmented control: **Due** / **All** (maps to
  `CardScope.due` / `CardScope.all` — see §1 reconciliation on naming).
  - Copy under the control, small/tertiary text: *"Due reviews what's due
    today · All studies the whole deck, including cards you've mastered."*
    The second clause is intentional — it signals consequence, not "safe
    drilling."
- Below: 2-column grid of square deck tiles (`GridView`, `crossAxisCount: 2`,
  `childAspectRatio: 1`, gap `14`).
- Each tile:
  - Positioned `Stack`: a single offset `Container` behind (`AccentPair.fill`
    at `opacity: 0.4`, inset so it peeks out ~8px past the **left** edge only
    — not top-right; this was iterated on and left-edge is the locked
    direction), and the white foreground tile on top, inset `8px` from the
    left so the accent sliver is visible.
  - Foreground: `border.hairline` 0.5px border, `borderRadius: 16`,
    centered column content: deck name (`fontWeight: FontWeight.w600`,
    `fontSize: 15`, centered, up to 2 lines) + a badge below.
  - Badge content depends on active segment:
    - **Due**: `"{n} due"` in the deck's accent text color on a
      `withOpacity(0.12)`-tinted background of the same accent, OR
      `"up to date"` in neutral gray if `n == 0`.
    - **All**: `"×{n} cleared"` where `n` is the per-deck run-through count
      from the aggregation provider (§7), OR `"not attempted"` (neutral gray,
      not "×0" — avoid a discouraging zero) if `n == 0`.
  - Deck's accent = its parent Course's `accent_color`, resolved via
    `AppTokens.accents[deck.course.accentColor]`.
- Trailing grid cell: dashed-border `Container` (`border.hairline`-derived
  dashed style, `+` icon, `text.tertiary`), tapping it also routes to
  `/deck-creator`. Purely a convenience duplicate of the shell's Create
  button — acceptable redundancy, not required to remove.

### 6.2 Study session screen (`/study/:deckId`)

Shared scaffold across all four card-type modes: top hairline progress bar,
card surface, mode-specific interaction area, rating row (Flip mode only —
other modes gate the rating row on their own completion condition, see
per-mode notes).

**Shared chrome:**
- Top: `2px` height, `border.hairline` track, filled portion in `blue.fill`
  (`#9DBDD2`), width = `completedCount / totalCount`.
- No page title/app bar. A leave/close affordance top-left is planned but not
  yet speced in detail — placeholder only, revisit before build (per explicit
  user note: "we'll improve it later, it's very simple" — do not over-invest
  here yet).

**Stacked-deck effect** (Flip mode's card surface, and reusable elsewhere):
- Two backing `Container`s behind the main card:
  - Layer 1: `top: 14, left: 10, right: 10`, fill `#EEF1F5`
    (or accent-tinted at low opacity if the study screen is accent-aware —
    TBD, default to neutral gray for now), `borderRadius: 28`.
  - Layer 2: `top: 7, left: 5, right: 5`, fill `#F5F7FA`, `borderRadius: 28`.
- **Frozen at session start** — do not reflow this visual if background sync
  pulls in new cards mid-session. Depth represents "the queue as it was when
  you started," not a live count.
- Main card: `Container`, white fill, `0.5px` `border.hairline`, `borderRadius: 28`,
  centered content, `GestureDetector` for tap-to-flip.

**Flip mode:**
- Tap card → flips (transition style per Settings: 3D flip via
  `Transform` + `AnimatedBuilder` on a rotation `Y` value, or fade+slide via
  `AnimatedSwitcher` — user-selectable, see §6.5).
- Rating row: 5 buttons (`0`–`4`), equal flex, `height: 40`, `borderRadius: 14`,
  `0.5px border.hairline`, white fill, `text.primary` label — **except button
  `4`**, which is filled with a **fixed** color, `#D06C60` (the `red` accent
  key's fill), regardless of the current deck's own accent. **Resolved:** do
  not derive button 4's color from `deck.course.accentColor`. "Mastered" is a
  single, consistent visual signal across every deck so it stays instantly
  recognizable no matter which course/accent you're studying in — letting it
  shift color per deck would undermine that recognizability.
- Swipe: `Dismissible` or raw `GestureDetector` with `onHorizontalDragEnd`
  velocity/distance threshold. Swipe-left → submit rating `0`. Swipe-right →
  submit rating `4`. Ratings `1`–`3` are button-only, unreachable by gesture.

**Cloze mode:**
- Text with inline tappable "blank" spans (`InkWell`-wrapped, styled as a
  filled chip pre-reveal, plain text post-reveal per-blank).
- No swipe gestures in this mode (tactile-only, per architecture invariant).
- Rating row: same 5-button row as Flip, **gated** — only rendered/enabled
  once every blank in the card has been individually revealed. Track
  per-blank revealed state in the card's local widget state, not global
  session state.

**List mode:**
- Vertically scrollable checklist, each item independently revealable (same
  tap-to-reveal chip pattern as Cloze, one item per row).
- Rating row appears once **every item has been interacted with** (tapped,
  regardless of scroll position) — do not gate on scroll-to-bottom.

**Feynman mode:**
- No text input anywhere in this mode.
- On card entry: card prompt visible immediately, but the timer does **not**
  start yet. A "Ready" button is shown; the countdown (per the
  **user-configured-at-session-start** duration, see §6.2.1) only begins once
  the user taps it. This gives the user a moment to read/compose their
  thoughts before the clock starts — **resolved**, this is the locked
  behavior, not the earlier auto-start version.
- Card prompt stays visible for the full duration, both before Ready is
  tapped and during the countdown (this was corrected from an earlier
  "typing" design — no `TextField` exists in this mode).
- Once Ready is tapped and the countdown is running, a "Finished" button is
  available at any time; tapping it or the timer reaching `0:00` both
  transition to the same next state (no distinction between early-finish and
  timeout). The Finished button is not shown during the pre-Ready state.
- At `0:00`: auto-advance, paired with `HapticFeedback.mediumImpact()`. No
  sound.
- Next state: rating row is available immediately (not gated on reveal). A
  "Reveal reference" button/chip is also present; tapping it opens a
  **dismissible modal overlay** (`showGeneralDialog` with a `barrierColor`
  scrim, not an inline widget) showing the reference answer. Tapping the
  scrim (outside the modal content) dismisses it. The rating row underneath
  remains tappable regardless of whether the modal was ever opened — reveal
  and rating are fully independent actions.

**6.2.1 — Feynman timer config:** chosen once at the *start of a Feynman
session* (applies to every card in that session), via a preset picker —
`30s / 60s / 90s / 120s`, default `60s`. Not a per-card setting, not a global
Settings default (though see §6.7 — Settings shows the *last-used* value, it
does not force it).

### 6.3 Mastery tab (`/mastery`)

All values sourced from Engine V2's local aggregation providers (§6, Engine V2
spec) — no bespoke queries written in the UI layer.

- Header "Mastery".
- Aggregate card: `overallMasteryProvider` value as a large percentage,
  `mutedFill` background, `borderRadius: 20`, thin progress bar beneath
  (`blue.fill`).
- "Deck completions" section: list of decks sorted by run-through count
  descending, each row showing deck name + `"×{n}"` badge
  (`text.primary`/`mutedFill` neutral styling — this is a plain count list,
  not accent-colored, since it's cross-deck).
- "Troublemaker cards" section: from the targeted `fail_count`-ordered query,
  each row shows card front-text excerpt, deck name, `"missed {n} times"`,
  and a severity badge. Severity thresholds are a **UI-only heuristic** (not
  an engine concept) — e.g. `fail_count >= 5` → "low" (red-tinted),
  `fail_count >= 3` → "fair" (amber-tinted), else no badge. Confirm exact
  thresholds during build; not load-bearing on any engine field.
- **Course rollups — resolved placement.** A horizontally scrollable row of
  compact course chips, inserted between the aggregate mastery card and the
  "Deck completions" section (so ordering top-to-bottom is: overall → by
  course → by deck → troublemakers, i.e. coarsest to finest grouping).
  - Each chip: fixed width ~120, `borderRadius: 16`, `0.5px border.hairline`,
    a thin left-edge accent bar (`4px` wide, full height, `AccentPair.fill`
    for that course — same visual language as the deck tile's left-accent,
    just simplified to a flat bar instead of an offset shadow, since these
    chips are small and a full stacked-shadow treatment wouldn't read well
    at this size) followed by: course name (1 line, ellipsis), then
    `"{masteryPercent}% · {deckCount} decks"` in `text.secondary`.
  - Rationale for a horizontal scroller over a grid/list: course count is
    likely small (a handful) but unbounded, and this keeps the section
    compact/skimmable rather than pushing the more detailed deck/troublemaker
    lists further down the screen.
  - Uses `CourseSummary.masteryPercent` and `.deckCount` directly — no new
    provider needed, this data already exists per Engine V2 §6.

### 6.4 Profile tab (`/profile`)

- Avatar (initials, `amber.fill`-tinted circle), name, email.
- Two stat blocks: streak, and aggregate mastery (reuse
  `overallMasteryProvider`).
  - **Streak is not yet backed by an aggregation provider.** Engine V2 §6
    already lists "Activity over time — sessions per day, from
    `study_sessions.started_at`" as speced-but-deferred; streak is that same
    underlying data (consecutive calendar days with at least one `completed`
    session), just reduced to a single integer instead of a full timeline.
    Like "times cleared," this should be **derived**, never a stored counter,
    to avoid the same last-write-wins raciness Engine V2 explicitly designed
    around for `mastery_count`. Add one small provider —
    `currentStreakProvider` — computed client-side from
    `study_sessions.started_at` (local/cached, same zero-network invariant as
    every other stat here). This is new engine-adjacent work, not yet built;
    sequence it alongside or just before U7 (§8).
- List card: "Account", "Subscription" rows (placeholders — exact fields
  TBD, not specified by product yet).
- "Sign out": outlined button (not filled), border+text in `red.text`
  (`#B0453A` — this is a truly hardcoded destructive-action color, not
  accent-derived, since it must stay recognizable as "sign out" regardless of
  the current deck's accent color). Tapping it opens a confirmation dialog;
  if there are unsynced local writes pending, the dialog must surface that
  explicitly (e.g., "You have unsynced progress. Sign out anyway?") rather
  than silently discarding it.
- A "leave/close" top affordance for Profile itself is not needed — Profile
  is a shell-branch tab, not a top-level route, so the bottom nav bar remains
  the way back.

### 6.5 Settings tab (`/settings`)

- "Study appearance" section: Card transition (3D flip / Fade & slide,
  segmented pill selector), Progress indicator (Hairline / Pill toggle,
  default Hairline).
- "Feynman mode" section: shows last-used timer preset as informational text
  (not an editable default — actual selection happens per-session, §6.2.1).
- "General" section: Send feedback (placeholder link), About.

### 6.6 Course Creator (`/course-creator`) — **blocked, see §7**

---

## 7. Blocked / not-yet-buildable

**Course Creator screen cannot be fully built against Engine V2 as speced.**
`CourseRepository`'s create/update/delete methods are explicitly "speced but
not exposed until the UI revamp" per Engine V2 §3.5 — meaning the write path
needs to be wired (repository methods + Riverpod providers) as part of this
UI work, coordinated with whoever owns the engine, not assumed already
present. Minimum viable screen: name field (text input), accent picker (8
fixed swatches per §3.2, single-select), deck multi-select/reorder (add
existing decks into this course — reassigns their `course_id`). Do not start
building this screen's data layer without confirming the create/update/delete
repository methods exist and match this shape.

---

## 8. Milestones

| # | Scope | Done when |
|---|---|---|
| **U1** | `AppTokens` theme extension, palette, geometry tokens (§3) | Tokens compile, resolvable via `Theme.of(context).extension<AppTokens>()` in a smoke-test widget; no hardcoded hex outside `AppTokens`'s own construction. |
| **U2** | Routing skeleton (§4) — shell + top-level routes, no real screens yet (placeholders) | Navigating between all 4 tabs preserves each branch's scroll/state; pushing `/study/:id`, `/deck-creator` hides the bottom bar; back returns to the originating tab. |
| **U3** | Shell chrome — floating glass nav bar, inline Create button (§5) | Bar renders correctly on a notched-device simulator (safe-area respected), Create button tap routes to `/deck-creator`. |
| **U4** | Decks tab — segmented Due/All control, deck grid tiles with accent (§6.1) | Switching segments swaps only the trailing badge, not deck order/list; tile accent color correctly resolves through `deck.course.accentColor`; zero-count states show the correct non-discouraging copy. |
| **U5** | Study screens — Flip, Cloze, List (§6.2, excluding Feynman) | All three modes function against a real `CardScope.due` session; swipe-left/right on Flip submit ratings 0/4 correctly; Cloze/List rating rows gate correctly on full-reveal. |
| **U6** | Feynman mode — timer, Finished button, reveal overlay (§6.2, §6.2.1) | Timer preset picker works at session start; timer auto-advances at 0:00 with haptic; reveal modal dismisses on outside-tap; rating is submittable with or without ever opening reveal. |
| **U7** | Mastery tab (§6.3) | All three sections render from the real Engine V2 aggregation providers, not mock data; troublemaker severity thresholds documented in code comments since they're UI-only heuristics. |
| **U8** | Profile & Settings (§6.4, §6.5) | Sign-out confirmation correctly detects and surfaces unsynced-writes state; all Settings toggles persist locally (`SharedPreferences`) and are read back correctly on relaunch. |
| **U9** | Course Creator (§6.6, §7) | **Blocked** until `CourseRepository` write methods exist — do not start until confirmed with engine owner. |

U1–U3 have no cross-dependencies and can be built in any order. U4 depends on
U1–U3. U5/U6 depend on U1–U3 (not on U4). U7 depends on Engine V2 milestone 17
being complete. U9 is blocked as noted.