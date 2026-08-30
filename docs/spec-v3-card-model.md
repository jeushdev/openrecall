# ActiveRecall — Card Model v3

## Status

This is the source of truth for the card model as of milestone **R3**. It
supersedes the parts of `docs/spec.md` (§4, §5, §6) that describe List mode, the
single `keyword`, and the List/Feynman multi-line trigger. Everything else in
`docs/spec.md`, `docs/engine-v2-spec.md` and `docs/ui-spec-v2.md` still holds.

Milestones:

- **R3** — schema + domain foundation (this doc). Multi-keyword column,
  `is_concept` flag, List mode removed. **Complete.**
- **R4** — Cloze type-to-answer (Levenshtein fuzzy match + "I was right"
  override) restored and extended to multiple keywords. **Complete.**
- **R5** — bulk import reworked to a multi-line block format that can produce
  concept cards and bulleted backs.

## What changed from v1/v2

| Area | v1 / v2 | v3 (this doc) |
|---|---|---|
| Study modes | Flip, Cloze, **List**, Feynman | **Flip, Cloze, Feynman.** List is removed. |
| Multi-line content | Its own "List" data shape, orientation-agnostic (`list_content.dart`'s `listContentOf`) | Just a Flip card with a bulleted `back`. No special type. |
| Keyword | One nullable `cards.keyword text`; "one keyword per card" locked (`docs/spec.md` §5) | `cards.keywords text[]` — zero or more. |
| Feynman trigger | Same as List: any card with 2+ lines on a side | `cards.is_concept = true`, and nothing else. |
| Feynman prompt / reference | The single-line side / the multi-line side (orientation-agnostic) | Always `front` / `back`. |

## The card model

A card is `front` + `back` (both `text not null`), plus:

- **`keywords text[] not null default '{}'`** — the words Cloze blanks. Each
  keyword must appear verbatim (case-sensitive) as a substring of the card's
  `front` or `back`; the editor validates this as chips are added
  (`keyword_validator.dart`). During Cloze study, **every occurrence of every
  keyword** is blanked (`cloze_blank.dart`).
- **`is_concept boolean not null default false`** — flags a card as worth a
  Feynman synthesis. Feynman-ing a bare term makes no sense, so only
  concept-flagged cards offer it.

There is still no stored `type`. `availableModes()`
(`lib/features/decks/domain/study_mode.dart`) computes a deck's modes at read
time:

- **Flip** — always.
- **Cloze** — any card with a non-empty keyword.
- **Feynman** — any card with `is_concept = true`.

## Feynman mode

A concept card's Feynman **prompt** is its `front`; the **reference** (revealed
after the timer) is its `back`, split on newlines into bullets
(`contentLines()`). Write the back as one point per line.

## Cloze mode

As of R4 the study surface is `ClozeTypeCard` (the type-to-answer card revived
from commit `1528747` and extended to the `keywords` list). Every keyword
occurrence across `front` then `back` becomes a numbered blank
(`cloze_blank.dart`'s `clozeSegments` / `clozeBlankAnswers`). The user fills the
blanks in reading order, one active at a time:

- A typed answer is fuzzy-matched on-device — `isClozeMatch` in
  `levenshtein.dart`: an exact match (case- and edge-punctuation-insensitive)
  always passes, otherwise the edit distance must be ≤ 1 for keywords of 6
  characters or fewer, ≤ 2 for 7+.
- A hit auto-advances to the next blank.
- A miss freezes on that blank showing a letter-by-letter diff (`letter_diff.dart`),
  the real keyword, and an **"I was right"** override.

The card's `mastery_level` is auto-derived — there is **no rating row**
(`docs/spec.md` §6): all blanks right on the first try → **Mastered**; any blank
overridden → **Familiar**; any blank missed without an override → **Forgotten**
(the worst blank wins). The derived `ClozeOutcome` is reported through
`SessionController.submitCloze`, which shares the same optimistic requeue / park
/ guarded-write path as Flip's `rate`.

A Cloze-eligible card whose keywords never literally appear has no blanks and
is treated as already correct.

## Storage

### Supabase (`supabase/schema.sql`)

`cards` has `keywords text[]` and `is_concept boolean`; the old `keyword` column
is dropped. The file carries an idempotent `do $$ … $$` block so it applies
cleanly to both a fresh project and one that predates R3 (folding each existing
`keyword` into a single-element `keywords` array). RLS (`cards_owner_via_deck`)
is unchanged — it joins through `decks.user_id` and references neither column.

### SQLite mirror (`lib/core/local_db/app_database.dart`)

`offline_cards` gains `keywords TEXT NOT NULL DEFAULT '[]'` (a JSON-encoded
string array) and `is_concept INTEGER NOT NULL DEFAULT 0`. The old singular
`keyword` column is **left in place, unread and unwritten** — the local-DB
migration framework and the schema-parity test only support `ALTER TABLE ADD
COLUMN`, never `DROP`. `_version` is 3; `upgradeToV3Statements` adds the two
columns.

Keywords and `is_concept` are authoring fields (online-only), so they never
enter the local→remote sync surface — `SyncService` only ever pushes
`mastery_level` / `fail_count`.
