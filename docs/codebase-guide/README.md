# Codebase Guide — read this to change the code yourself

This folder exists so that, without a coding agent, you can still answer the
only question that matters when you want to change something:

> **"I want to change this thing — which file do I open?"**

The existing `docs/*.md` files (`spec.md`, `ui-spec-v1.md`, `ui-spec-v2.md`,
`spec-v3-card-model.md`, …) are *decision records*. They say what was decided
and why. They do **not** tell you where the code is. That is what this guide
does.

---

## The six files

| File | What it gives you |
|---|---|
| `01-primer.md` | Flutter / Dart / Riverpod / go_router — the concepts you need to read any file here, taught with this repo's own code as the examples. **Read this first if you're not fluent in Flutter.** |
| `02-screen-map.md` | Every screen in the app: its route, its file, the sub-widgets it's built from, the providers that feed it, and where it navigates. **This is the lookup table.** |
| `03-architecture.md` | How the code is organised: the four layers, the theme/token system, the offline + sync machinery, routing, startup, and testing. |
| `04-study-engine.md` | A narrative walkthrough of the study session loop — the one genuinely complex subsystem, and the one where a careless edit does real damage. |
| `05-recipes.md` | "I want to X" → the exact files to touch, in order, with the verification step. Start here when you're not sure. |

---

## How to find things — the decision tree

- **Change how something *looks*** (colour, spacing, corner radius, font size)
  → `03-architecture.md` § "Theme & design tokens" first, then `02-screen-map.md`
  to find the specific screen/widget.
- **Change one screen's layout or wording**
  → `02-screen-map.md`, find the screen, open its file.
- **Change what data a screen shows**
  → `02-screen-map.md` tells you which *provider* feeds it; then
  `03-architecture.md` § "The repository sandwich" to trace where that data
  comes from.
- **Change how studying works** (ratings, the park rule, mastery maths, a mode)
  → `04-study-engine.md`.
- **Add, remove, or reorder a screen**
  → `03-architecture.md` § "Routing & auth gating", then `05-recipes.md`.
- **Add a field to a card / deck / course**
  → `05-recipes.md` § "Add a field to a card, deck or course" — it's a chain of
  ~6 files including a database migration, so follow the recipe.
- **Not sure** → `05-recipes.md`.

---

## Which of the *other* docs to trust

The `docs/` folder accumulated specs over time and they supersede each other.
Current authority:

| Doc | Status |
|---|---|
| `spec.md` | Original full spec. Still the source of truth for the **database schema**, offline design (§10), and performance rules — **but its §4/§5/§6 (card model, study modes) are superseded.** |
| `spec-v3-card-model.md` | **Authoritative for the card model.** List mode removed; cards have `keywords` (a list) + an `is_concept` flag; no `type` column. |
| `ui-spec-v1.md` | The original visual system (colours, radii, the 4-tab shell). Layout details partly superseded by v2. |
| `ui-spec-v2.md` | **Authoritative for presentation** where it disagrees with v1: the Decks-tab course accordion, deck-detail screen, unified import screen, card list. |
| `spec-v4-offline-authoring.md` | **Authoritative for offline** — extends offline from "study only" to full course/deck/card authoring offline. Supersedes build-order milestone 13. |
| `spec-v5-dark-mode.md` | **Authoritative for dark mode** and the theme selector. Supersedes the "dark mode deferred" note in ui-spec-v1 §3.1. |
| `engine-v2-spec.md` | The data-layer + aggregation work (courses table, `card_scope`, the Mastery-tab rollup providers). |
| `spec-web-mvp.md` | **Not built.** A plan for a web deployment. Ignore unless you're starting that. |
| `build-order.md` | The milestone list. Useful as history; milestone 13 is superseded by spec-v4, and the "milestone A–E" / "R1–R5" / "U1–U15" / "UX1–UX6" milestones in the git log came after it. |

Rule of thumb: **when a spec and the code disagree, the code wins** — the specs
were sometimes written ahead of implementation and not all details survived.

---

## The three commands

Run these from the repo root (`study-app-v1/`). You need the Flutter SDK
installed; for `flutter run` you also need an Android emulator or a plugged-in
Android phone with USB debugging on.

```bash
flutter pub get     # install dependencies (run once, and after editing pubspec.yaml)
flutter analyze     # static analysis / lint — must be clean before you commit
flutter test        # the full test suite — must be green before you commit
flutter run         # launch the app on a connected Android device/emulator
```

While `flutter run` is going, press `r` in its terminal for hot reload (most
edits show up in ~1 second) and `R` for a full restart. `flutter doctor` will
say "Android license status unknown" — that is known and harmless.

---

## The absolute rules (from `CLAUDE.md`) — don't break these

1. **No AI API calls anywhere.** Not for grading, not for anything. This is a
   cost decision, permanent.
2. **No custom backend.** The app talks to Supabase directly. There is no
   server to change.
3. **Study interactions must never block on the network.** Flipping a card,
   rating it, typing an answer — none of these may `await` a Supabase call,
   online or offline. Writes are queued and flushed in the background.
4. **`cards` has no `type` column.** Which study modes a card supports is
   computed at read time from its content. See `04-study-engine.md`.
5. **`updated_at` is set by a database trigger, never by app code.**
