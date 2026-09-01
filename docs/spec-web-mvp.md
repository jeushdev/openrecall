# spec-web-mvp — ActiveRecall on the web

Status: **plan only, not scheduled.** Owner decides when to run it.
Date: 2026-09-01.
Supersedes nothing. Complements `docs/spec.md` §10 (offline/sync) and
`docs/ui-spec-v2.md` (presentation).

---

## 1. Goal and non-goals

### Goal
Ship the existing Flutter app as a **hosted web build** reachable from any
modern browser, with the least code change that is still correct. The web
build is the same app, same Supabase project, same account — just a second
delivery channel alongside the Android APK.

### Non-goals for this release
- **Not a responsive desktop product.** The UI stays phone-first. On a wide
  viewport it renders in a centered phone-width frame, not a reflowed
  desktop layout. A real responsive pass, if it ever happens, belongs in a
  future UI milestone, not here.
- **Not installable.** No PWA manifest work beyond the generated default, no
  service worker, no offline app shell, no "add to home screen" polish.
- **No offline support on web.** The device-local SQLite mirror and the
  reconnect sync engine are Android-only. The web build talks to Supabase
  directly for every read and write. See §4.
- **No study reminders on web.** Local notifications cannot fire from a
  plain hosted page.
- **No dedicated Safari/iOS QA.** WebKit is best-effort: fix what is
  reported, do not block the release on it.
- No CI/CD automation in this spec beyond a single optional build check
  (§8). Deployment is Git-connected but the pipeline is not hardened.

---

## 2. Why this is a small change

Three properties of the current codebase make the port cheap:

1. **No custom backend.** Flutter talks to Supabase (Postgres + Auth +
   Storage) directly. RLS enforces ownership. All of that works unchanged
   from a browser origin — there is no server to port, and the anon key is
   already a public value.

2. **Auth is email/password only.** `AuthRepository` exposes `signUp`,
   `signInWithPassword`, `signOut`, `sendPasswordResetEmail`. No OAuth, no
   magic links, no deep-link redirect handling. Password reset opens
   Supabase's own hosted page. The only dashboard change needed is adding
   the deployed origin to the Site URL / redirect allow-list so the reset
   email's link returns to the right place.

3. **The offline layer is already optional.** `appDatabaseProvider`
   defaults to `null`; `main.dart` overrides it with a real
   `AppDatabase` only when `AppDatabase.open()` succeeds. When it is null,
   every local DAO store (`LocalDeckStore`, `LocalStudyStore`,
   `LocalCourseStore`, `LocalStatsStore`) runs as a no-op and the
   cache-first repositories fall through to the plain Supabase
   repositories. `pendingSyncProvider` / `pendingSyncCountProvider` already
   special-case "all stores are no-op" and return `false` / `0`. So
   "online-only" is a supported configuration today, exercised by the whole
   unit-test suite — the web build just makes it the production
   configuration for that target.

Study interactions stay non-blocking without the mirror: `SessionController`
applies each rating to in-memory Riverpod state synchronously and fires the
persistence calls with `unawaited(...)`. That is a controller-level design,
independent of whether a local mirror exists.

---

## 3. Approach: inline platform guards

**Chosen:** guard the handful of Android-only startup steps with `kIsWeb`
in the existing `lib/main.dart`, add one viewport-frame widget, and hide
the UI affordances that only make sense with a local mirror. Same entry
point for both targets.

**Rejected — `lib/platform/` abstraction layer** (conditional
`platform_io.dart` / `platform_web.dart` imports for DB open, notifications,
storage). This is the right structure *if* the web build later needs the
SQLite-WASM mirror or an iOS build lands, because then the divergence stops
being trivial. Today the divergence is ~5 small points and an abstraction
layer is unjustified indirection (YAGNI). Revisit when offline-on-web or
iOS is actually on the table.

**Rejected — separate `lib/main_web.dart` entry.** A second entry point
means a second place to keep the ProviderScope overrides correct. The
`kIsWeb` branches in one `main()` are easier to read and keep in sync.

---

## 4. Behavior on the web build

| Concern | Android (today) | Web (this spec) |
|---|---|---|
| Reads (decks, cards, sessions, stats) | cache-first: local mirror, then Supabase | Supabase directly |
| Writes (mastery, session progress, CRUD) | optimistic in-memory + `unawaited` Supabase push + local mirror fallback when offline | optimistic in-memory + `unawaited` Supabase push; **no fallback** |
| Study interaction latency | never blocks on network | never blocks on network (unchanged) |
| Losing connectivity mid-session | session continues from the mirror, syncs on reconnect | in-flight `unawaited` writes may fail silently; **the last rating(s) before a drop or a tab close can be lost** |
| Cross-session offline | full: downloaded decks study offline | none |
| Study reminders | local notifications | not available |
| Sync status chip / "offline · N" chip | shown when writes are queued | never shown (nothing is ever queued) |
| Deck "download" / "keep available offline" (pin) controls | functional | meaningless — hidden (§5.3) |

The mid-session data-loss window is the one real regression versus Android.
It is judged acceptable for v1: the writes are per-rating mastery deltas,
the session can be re-run, and mastery is guarded server-side
(`updateCardMasteryGuarded`). It must be listed in the release notes /
known-issues, not hidden.

---

## 5. Code changes

All changes are additive and guarded; none alter Android behavior.

### 5.1 `lib/main.dart` — skip Android-only startup on web

- Wrap the `AppDatabase.open()` block in `if (!kIsWeb)`. On web, `database`
  stays `null` and `appDatabaseProvider` is not overridden. (Belt-and-braces
  even though `sqflite` throws at runtime rather than at compile time on
  web — do not rely on the `catch`.)
- Wrap `NotificationService().init()` / `setEnabled(...)` in `if (!kIsWeb)`.
  `flutter_local_notifications` has no web implementation.
- `dotenv.load(fileName: '.env')` stays. `.env` is already in
  `flutter: assets:` and loads on web. **Note:** on web the file is served
  as a static asset and is publicly fetchable. This is acceptable — it
  contains only `SUPABASE_URL` and the anon/publishable key, both of which
  ship in the Android APK too and are safe by design under RLS. Do not put
  anything else in `.env`.

### 5.2 `lib/app.dart` — viewport frame

Add `WebAppFrame` (new widget, `lib/core/ui/web_app_frame.dart`) and wrap
`child` inside the existing `MaterialApp.router` `builder:`, *inside* the
`AnnotatedRegion`.

Behavior:
- No-op unless `kIsWeb`.
- No-op when the available width is below a breakpoint (`600` logical px) —
  a phone-sized browser window gets the normal full-bleed layout.
- Above the breakpoint: constrain the child to a fixed content width
  (`430` logical px, matching a large phone), center it horizontally, fill
  the gutters with `Theme.of(context).colorScheme.surfaceContainerHighest`
  (or the nearest existing neutral token — match `ui-spec-v2.md`), and clip
  the content to the frame.
- The frame must not intercept pointer events in the gutter in a way that
  breaks scrolling inside the content column.
- Constants (`_frameBreakpoint`, `_frameContentWidth`) live at the top of
  the file with a comment; no theme plumbing.

Open choice for implementation, not blocking: whether to also round the
content column's corners / add a hairline border on very wide viewports.
Default to plain (flat, full-height) unless it looks unfinished in review.

### 5.3 Hide mirror-only UI on web

Audit and gate behind `!kIsWeb` (or an existing "offline available"
predicate) every control that is inert without a local mirror:

- Settings → Notifications → "Study reminders" `SwitchListTile`
  (`settings_screen.dart` ~line 51). Hide the whole row on web; if that
  leaves the "Notifications" section header alone, hide the header too.
- Deck Library / Deck Overview: the "download deck", download-progress, and
  "keep available offline" (pin) affordances from milestones E2/E3. Grep
  for the pin toggle and `isDownloaded` / `isNoop` call sites and hide the
  controls on web.
- The sync-status chip (`SyncStatusChip`, "☁ offline · N") — verify it
  already renders nothing when the count is always 0. If it can still show
  a bare "offline" state from `connectivity_plus`, decide in review whether
  a genuine browser-offline indicator is worth keeping (it is accurate, so
  probably yes) or hiding for consistency.

The "you have unsynced work" warning in the Profile sign-out dialog
(`pendingSyncProvider`) already resolves to `false` on web — no change, but
confirm the dialog copy still reads correctly when that branch is always
taken.

### 5.4 Routing — clean URLs

Call `usePathUrlStrategy()` from `package:flutter_web_plugins` in `main()`
(web only) so routes are `/decks/…` not `/#/decks/…`. Pair with host-side
SPA fallback (§7). If this turns out to fight go_router's redirect logic in
testing, fall back to the default hash strategy — not worth a fight.

### 5.5 `web/` directory

Generate once with `flutter create --platforms=web .`. Keep the generated
`index.html`, `manifest.json`, `favicon.png`, and icons. Minimal edits
only:
- `<title>` and `manifest.json` `name` / `short_name` → "ActiveRecall"
  (or the current product name — match `pubspec.yaml` `description`).
- `theme_color` / `background_color` → the app's dark-mode background, so
  the initial white flash is minimised.
- No custom loading spinner work in v1.

### 5.6 Renderer

Use the Flutter default (`flutter build web` → CanvasKit). Do not pass
`--wasm` in v1 (narrower browser support, still stabilising). Accept the
~1.5 MB CanvasKit download on first load; it is CDN-cached thereafter.

---

## 6. Dependency audit

Every current dependency, web status:

| Package | Web | Notes |
|---|---|---|
| `supabase_flutter` | ✅ | Session persisted in browser `localStorage`. Verify restore-across-reload in the spike. |
| `flutter_riverpod`, `go_router` | ✅ | — |
| `connectivity_plus` | ✅ | Uses `navigator.onLine`. |
| `shared_preferences` | ✅ | Backed by `localStorage`. Theme, reminder pref, study-appearance prefs all fine. |
| `flutter_dotenv` | ✅ | Asset served publicly — see §5.1. |
| `package_info_plus` | ✅ | Reads from a generated file on web. |
| `http`, `uuid`, `path`, `timezone`, `reorderable_grid_view` | ✅ | Pure Dart / web-compatible. |
| `flutter_local_notifications` | ❌ | No web impl. Guarded out (§5.1, §5.3). Compiles; throws only if called. |
| `sqflite` | ❌ | No web impl. Never reached on web because `AppDatabase.open()` is skipped. Compiles; do not call. |
| `sqflite_common_ffi` | n/a | `dev_dependencies` only (tests). |

No dependency needs to be added or removed for v1. `flutter_web_plugins`
(SDK-bundled) is used for `usePathUrlStrategy`.

---

## 7. Hosting: Cloudflare Pages

**Recommendation: Cloudflare Pages.** Free tier: unlimited bandwidth,
unlimited requests, unlimited sites, 500 builds/month, global CDN, custom
domain + automatic TLS. Netlify and Vercel free tiers cap bandwidth at
100 GB/month and Vercel's Hobby tier forbids commercial use — Cloudflare
has neither limit.

**Fallback: Netlify**, if Cloudflare's build image lacks a usable Flutter
toolchain and installing it in the build step proves annoying. (Both
typically require installing Flutter in the build command since neither has
first-class Flutter support.)

Configuration:
- **Build command:** install Flutter, then `flutter build web --release`.
- **Output directory:** `build/web`.
- **SPA fallback:** `build/web/_redirects` containing `/*  /index.html  200`
  (Cloudflare Pages honours `_redirects`), so deep links / refreshes on
  client routes resolve. Add generation of this file to the build step or
  commit a `web/_redirects` that Flutter copies through.
- **Environment:** the build reads `.env` as a bundled asset, so `.env`
  must exist at build time. Either commit a web-specific `.env` (anon key
  only — safe) or have the build step write it from the host's environment
  variables. Prefer the latter to keep secrets-management uniform, even
  though the value is non-secret.
- **Deploy trigger:** connect the GitHub repo, deploy on push to `main`.
  Preview deploys per branch are a free bonus, not required.

Supabase dashboard change: add the production origin (and the
`*.pages.dev` preview origin if previews are used) to
**Authentication → URL Configuration → Site URL / Redirect URLs**, so the
password-reset email link returns correctly.

---

## 8. Testing

### Automated
- The existing `flutter test` suite runs on the Dart VM and is unaffected.
  It must stay green.
- `flutter analyze` must stay clean (project rule).
- Add **one** widget test for `WebAppFrame`: above the breakpoint the child
  is constrained to the content width; below it the child is passed through
  untouched. (Drive it by wrapping in a sized `MediaQuery`; the `kIsWeb`
  branch can be made testable by extracting the width logic into a pure
  function or accepting an `enabled` override param defaulted to `kIsWeb`.)
- No browser-driver / integration-test harness in v1.

### Manual smoke checklist (run per release, in Chrome + Firefox, then
Safari best-effort)
1. Cold load: app boots, no console errors, lands on sign-in.
2. Sign up a new account; sign out; sign back in with password.
3. Reload the page mid-session and after sign-in — session persists.
4. Password reset email arrives and its link resolves.
5. Create a course, a deck, cards (including a concept card and a
   multi-keyword card).
6. Run a full session to guaranteed mastery in each mode: Flip, Cloze,
   Feynman. Ratings stick after reload.
7. Profile study metrics update after a completed session.
8. Activity feed populates.
9. Dark mode / light mode / system toggle.
10. Deep link: paste a `/decks/<id>` URL into a fresh tab — resolves (SPA
    fallback works).
11. Wide desktop window: content is framed, centered, scrolls correctly.
12. Narrow window (~375 px): full-bleed phone layout, no frame.
13. Reminders toggle is absent from Settings; no download/pin controls on
    decks.

---

## 9. Rollout plan (phased)

Run when the owner decides the design is settled. Each phase is
independently committable.

### Phase 0 — spike (optional, ~2 hours, throwaway)
- `flutter create --platforms=web .`
- Add the `kIsWeb` guards in `main.dart` only (§5.1).
- `flutter run -d chrome`.
- Verify: app boots, sign-in works, session persists across a reload, one
  full study session completes and its ratings survive a reload.
- **Decision point:** any blocker here (session storage, a plugin that
  won't compile, a Supabase-from-browser surprise) is cheap to react to
  now. If clean, keep the `web/` dir and the guards; discard any throwaway
  probe code.

### Phase 1 — code changes
- `kIsWeb` guards finalised (§5.1).
- `WebAppFrame` + widget test (§5.2, §8).
- Hide mirror-only UI (§5.3).
- `usePathUrlStrategy` (§5.4).
- `web/` metadata edits (§5.5).
- `flutter analyze` clean, `flutter test` green.
- Commit: `feat: add web build target (milestone <N>)`.

### Phase 2 — deploy
- Cloudflare Pages project, Git-connected to `main`.
- Build command + output dir + `_redirects` (§7).
- `.env` provisioning in the build step.
- Supabase URL allow-list entry.
- First successful production deploy at a `*.pages.dev` URL (custom domain
  optional, later).

### Phase 3 — cross-browser pass
- Full manual smoke checklist (§8) in Chrome and Firefox.
- Safari/iOS best-effort pass; log issues, fix only blockers.
- Write the known-issues list (§4: mid-session write loss; no offline; no
  reminders; not installable) into the release notes / README.

---

## 10. Known limitations carried by this release

1. **Mid-session write loss window.** A connectivity drop or tab close can
   lose the last unsynced rating(s); there is no local mirror to replay
   from. Mitigated by server-side mastery guarding and the ability to
   re-run a session.
2. **No cross-session offline.** Closing the tab with no connectivity and
   reopening later offline gives an unusable app (same as any online web
   app).
3. **No study reminders.**
4. **Not installable, no offline app shell.**
5. **First load** pulls CanvasKit (~1.5 MB) plus the app bundle;
   CDN-cached afterward.
6. **Safari/iOS is best-effort.** Flutter web + browser-storage quirks on
   WebKit are not covered by a QA gate.

If any of 1–4 becomes unacceptable, the fix is the `lib/platform/`
abstraction plus `sqflite_common_ffi_web` for the mirror and a service
worker — a separate, larger spec, explicitly out of scope here.
