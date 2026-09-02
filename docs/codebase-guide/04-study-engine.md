# 04 — The study engine

This is the one genuinely complex subsystem. A careless edit here breaks the
core loop of the app, and some of the behaviour is subtle. Read the whole file
before changing anything under `lib/features/study/`.

All paths in this file are under `lib/features/study/` unless noted.

---

## The journey, end to end

### 1. Getting in

A deck tile on the Decks tab → `/deck/:deckId`
(`lib/features/decks/presentation/deck_detail_screen.dart`) → the user picks a
mode from `ModePicker` → the screen pushes `/study/:deckId` with a
`StudySessionArgs` (`presentation/study_session_args.dart`) carrying the chosen
`StudyMode`.

Route → widget: `app_router.dart` builds
`StudySessionScreen(deckId: ..., scope: CardScope.all, requestedMode: args?.mode)`.

> **`scope` is always `CardScope.all`.** The old "Due" view was retired
> (ui-spec-v2 §1). `CardScope` still exists as plumbing (`domain/study_session.dart`),
> the queue builder still honours it, and `study_sessions.card_scope` is still
> written — but the UI never selects `due` any more. Leave it alone.

### 2. Which modes a deck offers — computed, never stored

`cards` has **no `type` column** (a hard constraint from `CLAUDE.md`). Which
modes a card supports is derived at read time by
**`lib/features/decks/domain/study_mode.dart` → `availableModes(cards)`**:

| Mode | Condition | Helper |
|---|---|---|
| **Flip** | always (every card has a front and a back) | — |
| **Cloze** | at least one card has a non-empty keyword | `cardHasKeywords(card)` |
| **Feynman** | at least one card has `isConcept == true` | `cardIsConcept(card)` |

`cards.keywords` is a `text[]` (multiple keywords per card); `cards.is_concept`
is the **sole** Feynman trigger. (`cardIsMultiLine` still exists but is **not** a
mode trigger any more — List mode was removed. It only feeds a Deck-Overview
stat.)

### 3. Building the queue

`domain/session_queue_selection.dart` → **`selectSessionCards({cards, mode, cap, cardScope})`**:

1. Eligibility: `CardScope.due` → only cards below Mastered; `CardScope.all` →
   every card (Mastered included).
2. Filter to cards that support `mode` (`cardsSupportingMode`).
3. If `cap` is non-null (a "10 / 20 / 30" preset — `null` = "All"), take the
   first `cap`.
4. Creation order is preserved throughout.

If nothing qualifies → `EmptyQueueException` → the screen shows *"Nothing to
study — every card here is already mastered."*

**Sparse positions:** each queued card gets a `session_cards.position` in steps
of `kPositionStep = 1000`, not `1`. This is so a failed card can be re-inserted
*between* two existing positions without renumbering the rest of the queue.

### 4. Seeding the session

`application/session_controller.dart` → `start(...)`:

1. **Conflict rule:** if a live session for this deck in this mode already
   exists, silently re-attach. If a live session in a *different* mode exists,
   flush its pending writes first.
2. `_study.abandonActiveSessions(deckId)` — a new session abandons any old
   active one (spec §6).
3. Load the deck's cards local-first, timeout-bounded — *"a started session can
   never hang between the mode pick and the first card."*
4. `selectSessionCards(...)` → the ordered queue.
5. `_seedSession(...)` — inserts the `study_sessions` row + the `session_cards`
   rows, stamps `last_studied_at` (`markDeckStudied`), and builds the initial
   in-memory `StudySessionState`.

### 5. The loop

The state lives in **`domain/study_session_state.dart`** — an immutable
`StudySessionState` with a `SessionPhase` (`studying` / `parkPrompt` /
`completed`) and a list of `StudyQueueItem`s (`domain/study_queue_item.dart` —
each wraps a card with its `position`, `consecutiveFails`, `isParked`).

Every mode routes a result through **one path**:

- Flip: `SessionController.rate(FlipRating)` → `_applyResult(rating.level)`
- Cloze: `SessionController.submitCloze(ClozeOutcome)` → `_applyResult(outcome.masteryLevel)`
- Feynman: reveals content / runs the timer, then uses the **same 4-button
  rating row** as Flip → `rate(...)`

`_applyResult(masteryLevel)` is **synchronous and optimistic**: it advances the
in-memory queue *now* (via `StudySessionState.applyRating`, which returns the
next state plus a `RatingEffects` describing what to persist), then fires the
`cards` write and the `session_cards` write in the background. **The UI never
awaits these** (constraint 3 in the README).

### 6. Fail → requeue → park

- A card rated below Mastered is a "fail." Its `consecutiveFails` increments.
- **Requeue position** — `domain/requeue.dart` → `requeuePosition(...)`:
  roughly "3 cards ahead."
  - 4+ cards still ahead → slot strictly between the 3rd and 4th, if there's
    room in the sparse positions.
  - Otherwise (≤3 ahead, or too tight to interleave) → back of the queue.
  - Nothing ahead (last card) → repeat immediately (`currentPosition + 1000`).
- **Park after 3 consecutive fails** — `study_session_state.dart:240`,
  `static const int _parkThreshold = 3`. On the 3rd consecutive fail the phase
  becomes `parkPrompt`; the screen shows `ParkPromptDialog`. Confirm →
  `confirmPark()` sets the card aside (so an uncapped session can still
  terminate). Decline → `declinePark()` resets its `consecutiveFails` to 0 and
  keeps it in rotation.
- A **correct** answer resets `consecutiveFails` to 0.

### 7. Completion & summary

When every queued card is Mastered or parked → `SessionPhase.completed`.
`SessionController._finishSession()` writes the `study_sessions` completion and
builds a **`SessionOutcome`** (`domain/session_outcome.dart`): mastery %
before/after, cards studied, mastered, parked, first-try mastered, requeues.

`StudySessionScreen` then renders **`SessionSummaryView`**
(`presentation/widgets/session_summary_view.dart`). If any card was parked, a
**"Drill parked cards now"** button calls
`SessionController.startParkedDrill(...)` — a scoped session over exactly those
card ids, same mode, uncapped/until-mastered. **This deliberately bypasses
`selectSessionCards`** (spec §7).

---

## Mastery translation — the 0–4 scale

`cards.mastery_level` is `0..4`. `masteredLevel = 4`
(`lib/features/decks/domain/card.dart`). A card is "due" until it reaches 4.

**Flip** — `domain/flip_rating.dart`. The user picks one of four buttons; each
maps to a fixed level (note the **deliberate gap at 2** — the old "Okay" step
was removed from the UI but the surviving levels kept their numbers so old rows
stay valid):

| Button | `mastery_level` |
|---|---|
| Unfamiliar | 0 |
| Forgotten | 1 |
| Familiar | 3 |
| Mastered | 4 |

**Cloze** — `domain/cloze_outcome.dart`, reusing the Flip levels:

| Outcome | Level |
|---|---|
| `correct` (matched, exact or fuzzy) | 4 (Mastered) |
| `overridden` ("I was right") | 3 (Familiar) |
| `missed` | 1 (Forgotten) |

**Feynman** — self-checkoff of reference points, then the shared rating row.

**Deck / overall mastery %** — `domain/card.dart` →
`masteryPercentFromLevels(levels)`: average level, scaled from `0..4` to
`0..100`, rounded. Empty deck = 0%. Also `masteryPercentFromLevelSum(sum, count)`
for the aggregation layer.

---

## The per-mode widget files

### Flip
- `presentation/widgets/flip_card.dart` — the card; tap anywhere flips it.
- `presentation/widgets/rating_row.dart` — the 4 equal-flex buttons (shared by
  all modes).
- `domain/flip_rating.dart` — the enum + level mapping.

### Cloze
- `presentation/widgets/cloze_type_card.dart` — shows front + back with every
  keyword occurrence turned into a type-in blank.
- `domain/cloze_blank.dart` — locating/representing the blanks.
- `domain/levenshtein.dart` — edit-distance for fuzzy matching a typed answer.
- `domain/letter_diff.dart` — the per-letter diff shown as feedback.
- `domain/cloze_outcome.dart` — the outcome enum + level mapping.

### Feynman
- `presentation/widgets/feynman_card_view.dart` — prompt visible immediately, no
  text input anywhere, self-checkoff of points.
- `presentation/widgets/feynman_timer_picker.dart` — the per-session timer
  preset, chosen once before the first card.
- `presentation/widgets/feynman_reference_dialog.dart` — the "Reveal reference"
  overlay (only after the timer stops).
- `application/feynman_timer_providers.dart` — `lastFeynmanTimerProvider` (the
  Settings "last used" row reads this).
- `data/feynman_timer_preference.dart` — persists the last-used preset.

### Shared session chrome
- `presentation/widgets/stacked_deck.dart` — the layered surface behind the card.
- `presentation/widgets/study_progress_bar.dart` — the 2px top progress bar.
- `presentation/widgets/mode_picker.dart` — the pre-session mode choice.
- `presentation/widgets/park_prompt_dialog.dart` — the "park this card?" dialog.
- `presentation/widgets/session_summary_view.dart` — the end screen.

---

## `StudySessionScreen.build()` — which state is which

`presentation/study_session_screen.dart`. `build()` is a cascade of `if`s; in
render order:

1. **Forwarded-mode start** — `widget.requestedMode != null` and not yet
   started → kick off `_onModeSelected(mode)` in a post-frame callback, show a
   spinner.
2. **Reattach to a live/finished session** (`_shouldReattach`) →
   - complete + has outcome → `SessionSummaryView`
   - has a current card → `_ActiveBody` (the card + rating row)
   - else → spinner
3. **Started, still loading / errored** → spinner, or a `_Message`
   ("Nothing to study…" for `EmptyQueueException`, else "Couldn't start…").
4. **Feynman timer pick** (`_awaitingFeynmanDuration`) → `FeynmanTimerPicker`.
5. **Pre-session** (default) → watch `preSessionCardsProvider(deckId)`:
   loading → spinner; error → `_Message`; data → if one mode available,
   auto-start it; else `ModePicker`.

The park prompt is handled by a `ref.listen` at the top of `_ActiveBody.build()`
that fires `_handleParkPrompt()` when the phase becomes `parkPrompt`.

Sub-widgets `_Shell`, `_Spinner`, `_Message`, `_ActiveBody` are all file-private
in this same file.

---

## Do not break these

- **Study interactions never `await` the network.** `_applyResult` is
  synchronous; the writes are fire-and-forget with a background flush/retry
  (`_scheduleCardWrite` / `_flushCardWrite` / `_flushAllPendingWrites`). If you
  add an `await` to the rating path you've broken the core constraint.
- **`_parkThreshold = 3`** and the **requeue "3 ahead"** logic are tuned
  together and have dedicated tests (`requeue_test.dart`,
  `session_controller_test.dart`, `study_session_state_test.dart`). Change one,
  re-run all three, expect to update the tests.
- **`startParkedDrill` bypasses `selectSessionCards` on purpose.** Don't
  "consolidate" them.
- **List mode is gone.** `domain/list_content.dart`, `list_content_test.dart`,
  and `StudyMode` having no `list` value are all correct. Don't re-add it
  without a spec decision.
- **`CardScope` / `card_scope`** is dormant plumbing. The queue builder and DB
  column stay; the UI never picks `due`.
- The **level gap at 2** in `FlipRating` is intentional. Don't "fix" it.

---

## The tests that encode this behaviour

| File | Covers |
|---|---|
| `test/features/study/session_controller_test.dart` | start / conflict rule / seeding / drill |
| `test/features/study/study_session_state_test.dart` | the immutable state transitions |
| `test/features/study/requeue_test.dart` | requeue position maths |
| `test/features/study/session_queue_selection_test.dart` | queue eligibility + mode filter + cap |
| `test/features/study/flip_rating_test.dart`, `cloze_outcome_test.dart` | level mappings |
| `test/features/study/cloze_match_test.dart`, `cloze_blank_test.dart`, `letter_diff_test.dart` | Cloze matching |
| `test/features/study/feynman_mode_test.dart` | Feynman flow |
| `test/features/study/study_session_screen_test.dart` | the screen state machine |
| `test/features/study/pre_session_cards_provider_test.dart` | the local-first bounded card load |
