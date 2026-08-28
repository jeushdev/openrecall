# ActiveRecall — Feature & Screen Spec (v1 / Beta)

## Phase scope (locked from our discussion)
- **No billing, no paywall.** A `tier` column exists on `profiles` (default `'free'`) so nothing needs a schema change later, but nothing reads it yet.
- **No AI API calls anywhere in the app** — not for grading, not for anything server-side. Not sustainable to fund as an indie dev right now. The only "AI" touchpoint stays the copy-paste prompt into free web LLMs, which costs nothing.
- **Android only**, distributed as a direct `.apk` to classmates. No Play Store listing yet.
- **Flutter + Supabase** (Postgres + Auth + Storage) only — no custom backend.
- **Design principle, from your Gizmo frustration:** no artificial scarcity (no "hearts," no daily caps, no gating study access behind a mechanic). Whatever gets monetized later, it won't be *access to studying*.
- **Goal of this phase:** find out whether the mastery-loop / multi-modal approach is actually a better study experience, before any money or App Store overhead gets involved.

## Beta logistics
- **Distribution:** plain `.apk`, reshared manually when there's an update. No Firebase App Distribution for now — kept simple on purpose.
- **Feedback:** a Google Form sent to classmates, not an in-app feedback mechanism. Nothing to build for this.

---

## 1. Auth & Onboarding
- Splash screen → auth check → routes to Login or Deck Library
- Sign up / Log in — email + password only (Supabase Auth). Skipping Google sign-in for the beta.
- Forgot password (Supabase's built-in reset flow)
- No onboarding tour — one welcome screen at most
- **Profile row creation:** a Postgres trigger on `auth.users` insert automatically creates the matching `profiles` row. Not something the app itself has to remember to do after signup.

## 2. Deck Library & Dashboard
- List of decks: name, mastery % bar, due/total card count (due = `mastery_level` below Mastered — see §4's queue selection rule), last studied date (`last_studied_at` updates when a session starts, not when it completes — one clear trigger point)
- "+Create deck" button — prompts for a name, creates the deck row, then goes straight into the (now-empty) Deck Creator screen from §3, not a detour through Deck Overview first, since the obvious next action is adding cards
- Tap deck → Deck Overview
- Settings icon → Settings screen
- Per-deck offline indicator (cloud icon vs. downloaded icon — see §10)
- **Empty state:** no decks yet → prompt to create first deck, with a link to a small pre-made sample deck

## 3. Deck Creator & Ingestion — unified card model
- **One form for every card, no type picker:** Front (text), Back (text — single line or multiple lines), Keyword (optional text)
- **Keyword is optional.** Not every card needs one — plain flip-and-rate facts and List/Feynman-style cards often have no single word worth blanking. A card with no keyword just doesn't offer Cloze mode; everything else works normally.
- **Two ways to set it, same result either way:**
  - **Manual entry:** type it into the Keyword field, as it appears in Front or Back
  - **Bulk import:** wrap the word in `{{double braces}}` directly inside the Front or Back text. The parser extracts it into the Keyword field and strips the braces from the stored text — so however it was entered, what's actually stored is identical: clean text plus a separate keyword value.
- If the keyword text appears more than once in the card (manual entry case), every occurrence gets blanked during Cloze study — simplest consistent behavior, no need to guess which instance you meant.
- **Multi-line Back** is how you write List/Feynman-style content — one point per line. No separate type needed; see §5 for how that content gets used.
- Bulk paste box: parses `FRONT | BACK` — keyword marked inline with `{{}}` if present, no separate column needed. Only one `{{}}` pair is used per card; the live preview flags any card with more than one.
- Live syntax preview before committing — show which lines parsed and which failed, don't silently drop bad lines
- "Copy AI Prompt" button — copies an ingestion prompt asking for `FRONT | BACK` with an optional single `{{keyword}}` marked inline, for pasting into any web LLM
- Edit / delete individual cards after import
- **Empty state:** new deck, zero cards → prompt to add manually or bulk-paste, "Copy AI Prompt" front and center
- Creating/editing decks and cards requires connectivity (see §10) — the create/edit affordances should be disabled or hidden while offline, not left to fail silently

## 4. Deck Overview & Mode Selector
- Deck stats: mastery %, card count, how many have a keyword / multi-line back
- **"Troublemaker cards"** — cards with high lifetime `fail_count`. (Not "parked" cards — parking is session-scoped and doesn't persist past its own session; see §6.)
- "Add cards" entry point back into §3's screen — Deck Overview isn't just for starting sessions, it's also where you return to add more cards to an existing deck later
- **Mode buttons are computed, not stored per card, and only enabled if the deck actually has a qualifying card:**
  - Flip & Rate — always available (every card has front + back)
  - Cloze Type-in — shown/enabled only if at least one card in the deck has a keyword set
  - List Unmask — shown/enabled only if at least one card has 2+ lines on either side
  - Feynman Synthesis — same trigger as List (see §5)
  - Whichever side is the multi-line one is treated as "the content"; the other side is the prompt. Works regardless of whether you write definition-first or term-first.
- Session length toggle: "study until 100% mastery" (uncapped) vs. a capped session (fixed presets — e.g. 10/20/30/All — rather than freeform number entry, to avoid invalid inputs). Capping limits how many *distinct cards* enter the session queue — each card that does enter still loops via requeue/park exactly as in an uncapped session. Capping controls breadth, not how hard any one card is worked.
- **Session queue selection — the rule "due" actually means:** a new session's queue starts as every card in the deck with `mastery_level` below Mastered, then **filtered to only cards that structurally support the study mode you picked** (Flip has no filter, since every card qualifies; Cloze filters to cards with a keyword; List/Feynman filter to cards with 2+ lines on either side). A capped session's cap applies *after* this filter, not before. This filtered-and-capped set is what gets written into that session's `session_cards`. This one rule is what §2's due count is counting (unfiltered, deck-wide), what a capped session draws its cards from, and why previously-parked cards reappear in the next session automatically — parking never touched `mastery_level`, so a parked card is still just "not yet Mastered" and falls right back into the pool for whichever mode you pick next. New cards default to `mastery_level = 0`, so they're included with no special-case logic needed.
- **Empty state:** deck has cards, but none are due/parked right now → "all caught up" state, no forced action

## 5. Study Execution Screens
- **5A — Flip & Rate:** works on literally every card, no exceptions
- **5B — Cloze Type-in:** blanks the single keyword wherever it appears, Levenshtein fuzzy match, letter-by-letter diff feedback, manual "I was right" override
- **5C — List Unmask:** shows the single-line side as the prompt, reveals each line of the multi-line side in order, one tap at a time, scored on reveals-before-recall
- **5D — Feynman Synthesis:** shows the single-line side as the topic prompt, countdown timer starts, you free-write your own explanation, then compare it against the multi-line side's points and check off what you covered
- Shared across all: progress indicator, exit-and-resume (exiting returns to Deck Overview), "park this card?" after 3 consecutive fails
- **Parking isn't just a courtesy — it's what actually guarantees an uncapped session ends.** "Study until 100% mastery" only terminates once every card in the queue is either Mastered or parked. Without parking, one genuinely stubborn card would keep getting requeued forever, since nothing else in the design would stop it from being drawn again indefinitely.
- **What counts as a "fail" (drives both requeuing and the park counter):** any mastery result short of Mastered — see §6. One definition, used the same way regardless of which mode produced the result.
- **Requeue mechanics:** "3 positions ahead" needs `session_cards.position` values to be sparse (steps of 1000, not 1) so a requeue can slot in between existing values without renumbering the rest of the queue.

### Why List and Feynman share one data shape
A List card and a Feynman card are the same underlying shape — a short prompt on one side, key points as separate lines on the other. The only difference is which button you tap to study it: "reveal these one at a time" (List) or "write your own explanation, then compare it to these" (Feynman). It doesn't matter whether you wrote the multi-line part in Front or Back — whichever side has multiple lines is treated as the content, the other side is the prompt. Write cards in whatever order feels natural (definition-first or term-first); the app figures out the rest. (Edge case: if both sides end up multi-line, Back is treated as the content side by default, just to have a consistent rule.)

### Simplifications locked in this round
- **One keyword per card, not several.** The original doc allowed multiple `{{blanks}}` per card with auto-advancing inputs — dropped for v1. Want to quiz two different words from one fact? That's two cards, not one card with two tracked blanks.
- **Keyword is typed, not tap-to-select.** You retype the word into a small field rather than tapping to highlight it in your text — much simpler to build reliably, barely slower to use.

## 6. Mastery Tracking — one number per card, shared across all modes
Since any card can now be studied through multiple modes, all of them have to update the *same* mastery value — otherwise "guaranteed mastery" and deck-level mastery % don't mean anything consistent.
- Every card has exactly one `mastery_level`, using the Unfamiliar/Forgotten/Okay/Familiar/Mastered scale from Synapse — not one value per mode
- Each mode translates its own raw result into that same scale and updates the one stored value:
  - **Flip** — user picks the rating directly, unchanged
  - **Cloze** — auto-derived: correct on first try → Mastered; corrected after the manual override → Familiar; missed → Forgotten
  - **List** — auto-derived from reveal ratio: fully recalled before any reveal → Mastered; partial reveals → Familiar/Okay; mostly revealed → Forgotten
  - **Feynman** — auto-derived from the self-checkoff ratio: everything covered → Mastered; gaps → Okay/Familiar (missed points spawn the gap mini-deck, per the original doc)
- This means `mastery_level` and lifetime `fail_count` live once per card in the schema. `consecutive_fails` and `is_parked` are **session-scoped** — they live on `session_cards`, reset every new session, and do not persist on the card itself. Parking is a within-session safety valve, not a lasting label.
- **"Fail" is defined once, used everywhere:** any result short of Mastered counts as a fail. That single check drives both the requeue rule and the increment of `session_cards.consecutive_fails` — no separate per-mode fail definitions needed.
- **Deck-level mastery %** = average of `mastery_level` across all cards in the deck, scaled from the 0–4 range to 0–100%. Shown on Deck Library, Deck Overview, and as the Session Summary delta (before vs. after the session).

## 7. Session Summary
- Mastery delta for the session (+X%) — deck mastery % before vs. after
- Recall metrics for the session's study mode (a session is conducted in exactly one mode — see §4/schema `study_mode`)
- One-tap "drill parked cards now" — reads this session's own `session_cards` where `is_parked = true`; this is the only place parked cards are ever surfaced, since parking doesn't persist past the session (see §6). This is a deliberate exception to §4's normal queue-selection rule — a scoped session seeded from this one specific prior session's parked set, not the full-deck "everything below Mastered" pool. It reuses the same `study_mode` as the session being drilled, since that's the mode context those cards were parked under.
- "Done" — returns to Deck Overview

## 8. Notifications
- Local push reminders for parked/unfinished cards from your **most recent session** — that's the only "due" concept that exists for v1
- Stays meaningful even after a new session starts on that deck: parked-or-not, any card still below Mastered reappears in every new session's queue automatically (§4), so the reminder doesn't go stale just because a session happened in between
- Explicitly not blocked on the SM-2 decision (§ Open decisions #1) — no daily-due scheduling exists yet, so there's nothing to wait on. If SM-2 gets added later, this screen gets richer, not rebuilt.

## 9. Settings
- Account: email shown, log out, delete account
- **Account deletion needs a Supabase Edge Function (service role key)** — the client SDK can't delete a user's own `auth.users` row directly. Once that fires, everything else (decks, cards, sessions) cascades automatically through the existing FK design.
- Notification preferences
- About/version

## 10. Offline & Sync — Google Docs model
- Default is online — reads/writes go straight to Supabase, no local caching unless requested
- Per-deck "Available offline" toggle downloads that deck's cards into local SQLite
- A deck that isn't downloaded and has no connection simply isn't available — no error state to design around
- **Offline is study-only, not editing.** You can fully run study sessions on a downloaded deck with zero connectivity, but creating/editing decks or cards requires connectivity. This keeps the sync surface to "study results," never "content," which avoids a whole category of conflicts for no real loss — the offline use case is studying on the bus, not authoring new cards there.
- **What's cached locally per downloaded deck:** `cards` (front/back/keyword as a read-only mirror; `mastery_level` and `fail_count` *are* written locally during offline study), plus full local `study_sessions` and `session_cards` — sessions can be started and finished entirely offline.
- **Sync mechanism:** every local table has one extra column Supabase doesn't have — `is_synced` (boolean). Defaults `true` when pulled down, flips to `false` the moment a local write happens. On reconnect: every row with `is_synced = false` gets upserted to Supabase, in order `cards` → `study_sessions` → `session_cards` (dependency order), then flips back to `true` once confirmed. Last-write-wins by `updated_at` handles the rare conflict — no merge UI needed.
- New sessions created fully offline use a client-generated UUID from the start, so there's no "swap the temporary ID for a real one" step once synced
- `available_offline` is a device-local preference, not synced app data
- **Row Level Security is a Supabase/Postgres concept only — it does not apply to local SQLite,** which is just a private file on the user's own device. Nothing to build there for access control.
- Not building: multi-device conflict resolution — out of scope for the beta

---

## Performance & Responsiveness
- **Core principle: study interactions never wait on the network.** During any active session — online or offline — the UI updates immediately from local state; Supabase writes fire in the background and aren't awaited before the user can move to the next card. This is distinct from the offline sync mechanism in §10 — that exists for *durability* while disconnected; this exists for *responsiveness* while connected. Solving one doesn't solve the other.
- **"Local state" means two different things depending on the deck.** For a **downloaded** deck, it's the SQLite mirror from §10 — durable, survives an app kill. For a **non-downloaded** deck, there's no local table at all (per §10), so it's just in-memory app state for that session. Cheaper to build, but honest trade-off: an app kill mid-session on a non-downloaded deck loses that session's progress, since nothing durable was ever written. Acceptable for a beta; if it matters later, the fix is extending §10's local-mirror pattern to non-downloaded decks too.
- **Background writes are guarded by the same `updated_at` discipline as offline sync — never a blind update.** A requeued card can genuinely get rated a second time before its first write confirms (that's what "requeue 3 positions ahead" produces on a fast-moving session). Without checking `updated_at` before applying, the two writes could arrive out of order and the older one could silently overwrite the newer one.
- **Cloze fuzzy matching runs entirely on-device.** It's a plain string algorithm — no network involvement, ever.
- **Sync-on-reconnect batches its pushes**, not one row per network call — matters if a session queued up a lot of changes while offline.
- **Bulk-paste live preview (§3) debounces its parsing** rather than re-parsing on every keystroke, so editing a large pasted batch doesn't lag.
- **Deck/card lists use lazy-loaded (virtualized) rendering**, not rendering every row up front.
- **Foreign key columns are indexed** — see the schema below; Postgres doesn't index these automatically the way it does primary keys.

---

## Open decisions — status
1. **Layer SM-2 spaced repetition on top of the mastery loop?** → Still open, deferred.
2. ~~Auto-grade Feynman via AI API~~ → **Decided: no.** Not viable to fund per-call API costs right now.
3. **P2P/QR deck transfer?** → Skip for beta.

## Data Model (Schema)

**Session-conflict rule, carried over from Synapse:** starting a new session on a deck that already has an active one marks the old one `abandoned` before the new one starts — same rule Synapse already uses, no reason to invent a different one here.

**`updated_at` reliability:** since the entire sync design leans on `updated_at` for last-write-wins conflict resolution, it's set by a database trigger on every `UPDATE`, not left to the app to remember on each write path.

```sql
-- profiles: app-specific fields on top of Supabase's built-in auth.users
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  tier text not null default 'free',
  created_at timestamptz not null default now()
);
-- trigger: auto-insert a profiles row whenever auth.users gets a new row

-- decks
create table decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  last_studied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- cards — the unified front/back/keyword model
create table cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references decks(id) on delete cascade,
  front text not null,
  back text not null,
  keyword text,
  mastery_level smallint not null default 0,  -- 0 Unfamiliar .. 4 Mastered
  fail_count integer not null default 0,      -- lifetime, feeds Troublemaker Cards
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- study_sessions — one row per study session, resumable
create table study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  deck_id uuid not null references decks(id) on delete cascade,
  status text not null default 'active',         -- active | completed | abandoned
  study_mode text not null,                      -- flip | cloze | list | feynman — which mode this session was studied in
  length_mode text not null default 'uncapped',  -- uncapped | capped (renamed from session_mode to avoid confusion with study_mode)
  capped_length integer,                         -- only set if length_mode = 'capped'
  mastery_delta smallint,
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

-- session_cards — the queue + loop-prevention table, entirely session-scoped
create table session_cards (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references study_sessions(id) on delete cascade,
  card_id uuid not null references cards(id) on delete cascade,
  position integer not null,                      -- sparse (steps of 1000) so requeues don't need renumbering
  consecutive_fails smallint not null default 0,  -- resets on a pass, dies with the session
  is_parked boolean not null default false        -- session-scoped, unrelated to cards.fail_count
);
```

**Local SQLite mirror (per downloaded deck):** same `cards`, `study_sessions`, `session_cards` shapes as above, plus one extra local-only column, `is_synced` (boolean), on each. See §10 for the sync mechanism this supports.

**Indexes** (see Performance & Responsiveness above — not automatic on foreign keys in Postgres):
```sql
create index on decks (user_id);
create index on cards (deck_id);
create index on study_sessions (user_id);
create index on study_sessions (deck_id);
create index on session_cards (session_id);
create index on session_cards (card_id);
```

**On purpose, not by accident, still not in this schema:**
- No `ease_factor` / `interval_days` / `next_review_date` on cards — that's SM-2 machinery, and SM-2 is still deferred. Adding it later is a clean additive migration.
- `mastery_level` is a plain 0–4 integer, not Synapse's 0/1/2/3/5 scale — that gap at 4 only existed for Synapse's real SM-2 math, which doesn't apply here.

**RLS ownership pattern:** `profiles`, `decks`, `study_sessions` have a direct `user_id`/`id` column → straightforward `= auth.uid()` policy. `cards` and `session_cards` have **no direct owner column on purpose** (same call Synapse made) — their policies check ownership through a join (`cards` → `decks.user_id`, `session_cards` → `study_sessions.user_id`). This is exactly the pattern that's easy to get subtly wrong — worth personally reading the generated policy SQL rather than assuming it's correct.

## Card model (field-level detail)
Every card has exactly three content fields, described in full in §3:
- `front` (text, required)
- `back` (text, required — one line or several)
- `keyword` (text, optional — must be a substring of front or back)

There is no stored `type` column. Which study modes are available is computed from front/back/keyword at read time (see §4/§5), not chosen when the card is created.

## Error states
- Bad bulk-paste line: shown inline with a reason, never silently dropped
- Network drop mid-session on a non-downloaded deck: pause session, retry prompt, don't lose in-progress ratings until synced
- Supabase auth errors: standard invalid-credentials / already-registered messaging
- Attempting to create/edit a deck or card while offline: create/edit controls disabled or hidden, not left to fail on submit