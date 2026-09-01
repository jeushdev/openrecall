# Web MVP — Phase 1 (code changes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Flutter app build and run correctly as a hosted web target, with all Android-only startup and all mirror-only UI guarded out, plus a phone-width viewport frame on wide browsers.

**Architecture:** Inline `kIsWeb` guards in the single `lib/main.dart` entry point (no `lib/platform/` abstraction, no second entry). One new stateless widget, `WebAppFrame`, wraps the router content in `lib/app.dart`. Mirror-only affordances are hidden behind `!kIsWeb` at each call site. Clean URLs via `usePathUrlStrategy()` on web only.

**Tech Stack:** Flutter (Dart), `flutter_riverpod` 3.x (manual providers), `go_router` 18, `flutter_web_plugins` (SDK-bundled), CanvasKit renderer.

**Spec:** `docs/spec-web-mvp.md` — this plan implements **Phase 1** (§9). Phase 0 (spike) groundwork is already present but uncommitted: the `web/` directory exists (`flutter create --platforms=web .` was run) and `lib/main.dart` already guards `NotificationService().init()` and `AppDatabase.open()` with `if (!kIsWeb)`.

## Global Constraints

- **No AI API calls anywhere.** Not relevant to this plan, but never add one.
- **No custom backend.** Flutter talks to Supabase directly; unchanged on web.
- **All changes are additive and guarded — none alter Android behavior.** Every branch added in this plan is `kIsWeb` / `!kIsWeb` gated or defaulted to the current behavior on non-web.
- **Product name in web metadata is `OpenRecall`** (matches `MaterialApp.title`, the `open_recall` package name, and the `pubspec.yaml` description). Not "ActiveRecall".
- **Web is online-only.** No local SQLite mirror, no reconnect sync, no reminders. `appDatabaseProvider` stays `null` on web (already handled in `main.dart`).
- **Study interactions must never block on a network call.** Unchanged — `SessionController` applies ratings to in-memory state synchronously and pushes with `unawaited(...)`.
- `flutter analyze` must be clean and `flutter test` must be green before committing (project rule).
- Conventional commits. This project commits milestone work directly to `main`.
- **This machine has no Chrome.** Any manual `flutter run` / `flutter build` verification uses **Edge** (`-d edge` / `flutter build web`). Do not suggest Chrome.
- `§5.3` decision for this plan: **hide mirror-only UI at every call site, including the currently-unrouted legacy screens** (`SettingsScreen`, `DeckOverviewScreen`, `DeckLibraryScreen`, `OfflineToggle`), so they are web-safe if/when rewired. `SyncStatusChip` and `OfflineBanner` are **kept** — with a null local mirror their queued-count is always 0, so they render nothing while online and only surface an accurate "you're offline" indicator when the browser is actually offline.

---

## File Structure

**New files:**
- `lib/core/ui/web_app_frame.dart` — the `WebAppFrame` widget: a no-op except on web above a width breakpoint, where it centers the app in a fixed phone-width column with neutral gutters. One responsibility: the wide-viewport frame. Width/enable logic is exposed as a testable `bool` parameter.
- `test/core/ui/web_app_frame_test.dart` — the single new widget test required by §8.

**Modified files:**
- `lib/main.dart` — add `usePathUrlStrategy()` on web (§5.4).
- `pubspec.yaml` — add the SDK-bundled `flutter_web_plugins` dependency.
- `lib/app.dart` — wrap the router `child` in `WebAppFrame` inside the existing `builder:` (§5.2).
- `lib/features/decks/application/decks_tab_view.dart` — never mark a tile `isLockedOffline` on web (§5.3).
- `lib/features/decks/presentation/widgets/offline_toggle.dart` — render nothing on web (§5.3).
- `lib/features/decks/presentation/deck_overview_screen.dart` — suppress the "Update offline copy" menu item on web (§5.3, legacy screen).
- `lib/features/decks/presentation/deck_library_screen.dart` — never pass the `offline` badge flag on web (§5.3, legacy screen).
- `lib/features/settings/presentation/settings_screen.dart` — hide the "Notifications" section (header + reminders switch + divider) on web (§5.3, legacy screen).
- `web/index.html` — title, description, apple-mobile-web-app-title (§5.5).
- `web/manifest.json` — name, short_name, description, theme/background color (§5.5).

**Also committed (Phase 0 groundwork, already on disk, uncommitted):**
- `web/` (entire generated directory, minus the metadata edits in Task 4)
- `lib/main.dart` (existing `!kIsWeb` guards)
- `.metadata` (`- platform: android` → `- platform: web` line from `flutter create`)
- `analysis_options.yaml` (`web/**` added to the analyzer `exclude:` list)
- `pubspec.lock` (regenerated)

**Explicitly NOT touched / NOT committed by this plan:** `docs/codebase-guide/` (unrelated untracked docs). Stage files explicitly; never `git add -A`.

---

## Task 1: `WebAppFrame` viewport frame + widget test

**Files:**
- Create: `lib/core/ui/web_app_frame.dart`
- Test: `test/core/ui/web_app_frame_test.dart`
- Modify: `lib/app.dart` (wrap router child)

**Interfaces:**
- Consumes: `AppTokens` theme extension (`lib/theme/app_tokens.dart`) for the gutter color (`mutedFill`).
- Produces:
  - `class WebAppFrame extends StatelessWidget` with a const constructor
    `WebAppFrame({Key? key, required Widget child, bool enabled})`.
    `enabled` defaults to `kIsWeb`. When `enabled` is `false`, `build` returns
    `child` unchanged. When `true` and the `MediaQuery` width is
    `>= kWebFrameBreakpoint`, `child` is constrained to `kWebFrameContentWidth`,
    centered, clipped, on a `mutedFill` ground; below the breakpoint `child` is
    returned unchanged.
  - `const double kWebFrameBreakpoint = 600.0;`
  - `const double kWebFrameContentWidth = 430.0;`

- [ ] **Step 1: Write the failing test**

Create `test/core/ui/web_app_frame_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_recall/core/ui/web_app_frame.dart';
import 'package:open_recall/theme/app_theme.dart';

const _childKey = Key('framed-child');

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: WebAppFrame(
          enabled: true,
          child: SizedBox.expand(child: ColoredBox(color: Color(0xFF00FF00), key: _childKey)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('above the breakpoint the child is constrained to the content width',
      (tester) async {
    await _pumpAt(tester, const Size(1200, 900));
    expect(tester.getSize(find.byKey(_childKey)).width, kWebFrameContentWidth);
  });

  testWidgets('below the breakpoint the child is passed through full-width',
      (tester) async {
    await _pumpAt(tester, const Size(375, 800));
    expect(tester.getSize(find.byKey(_childKey)).width, 375);
  });

  testWidgets('disabled is always a pass-through even on a wide viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WebAppFrame(
            child: SizedBox.expand(child: ColoredBox(color: Color(0xFF00FF00), key: _childKey)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_childKey)).width, 1200);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/ui/web_app_frame_test.dart`
Expected: FAIL — `web_app_frame.dart` does not exist / `WebAppFrame` undefined.

- [ ] **Step 3: Write the implementation**

Create `lib/core/ui/web_app_frame.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Width at or above which the web build renders inside a centered phone-width
/// frame instead of full-bleed. Below it, a phone-sized browser window gets the
/// normal layout (spec-web-mvp §5.2).
const double kWebFrameBreakpoint = 600.0;

/// The content column width used above [kWebFrameBreakpoint] — a large phone.
const double kWebFrameContentWidth = 430.0;

/// Constrains the app to a centered phone-width column on wide web viewports
/// (spec-web-mvp §5.2). The web build is phone-first; this is not a responsive
/// desktop layout, just a frame so the UI isn't stretched across a monitor.
///
/// A no-op unless [enabled] (defaults to [kIsWeb]) and the viewport is at least
/// [kWebFrameBreakpoint] wide. Wrapped around the router content in
/// `lib/app.dart`, inside the `MaterialApp.router` builder.
class WebAppFrame extends StatelessWidget {
  const WebAppFrame({super.key, required this.child, this.enabled = kIsWeb});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    if (MediaQuery.sizeOf(context).width < kWebFrameBreakpoint) return child;

    final tokens = Theme.of(context).extension<AppTokens>()!;
    return ColoredBox(
      color: tokens.mutedFill,
      child: Center(
        child: ClipRect(
          child: SizedBox(width: kWebFrameContentWidth, child: child),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/ui/web_app_frame_test.dart`
Expected: PASS (all three cases).

- [ ] **Step 5: Wire it into `lib/app.dart`**

In `lib/app.dart`, add the import:

```dart
import 'core/ui/web_app_frame.dart';
```

In the `MaterialApp.router` `builder:`, wrap the `AnnotatedRegion`'s child. Change:

```dart
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? AppTheme.darkOverlay : AppTheme.lightOverlay,
          child: child ?? const SizedBox.shrink(),
        );
```

to:

```dart
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? AppTheme.darkOverlay : AppTheme.lightOverlay,
          child: WebAppFrame(child: child ?? const SizedBox.shrink()),
        );
```

- [ ] **Step 6: Run the full suite + analyze**

Run: `flutter test` then `flutter analyze`
Expected: all green, analysis clean.

- [ ] **Step 7: Commit**

```bash
git add lib/core/ui/web_app_frame.dart test/core/ui/web_app_frame_test.dart lib/app.dart
git commit -m "feat: add the web viewport frame"
```

---

## Task 2: Clean URLs on web (`usePathUrlStrategy`)

**Files:**
- Modify: `pubspec.yaml` (add `flutter_web_plugins`)
- Modify: `lib/main.dart` (call `usePathUrlStrategy()` on web)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing consumed by later tasks. Side effect only: web routes become `/decks/…` instead of `/#/decks/…`.

- [ ] **Step 1: Add the SDK dependency**

In `pubspec.yaml`, under `dependencies:` (keep alphabetical among the SDK entries — put it right after the `flutter:` sdk block, before `flutter_dotenv`):

```yaml
  flutter_web_plugins:
    sdk: flutter
```

- [ ] **Step 2: Install**

Run: `flutter pub get`
Expected: resolves cleanly; `pubspec.lock` updates.

- [ ] **Step 3: Call `usePathUrlStrategy()` on web**

In `lib/main.dart`, add the import (with the other `package:flutter/...` / package imports):

```dart
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;
```

Immediately after `WidgetsFlutterBinding.ensureInitialized();`, add:

```dart
  // Clean URLs on web: `/decks/…` rather than `/#/decks/…` (spec-web-mvp §5.4).
  // Paired with a host-side SPA fallback in Phase 2. No-op on Android.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
```

- [ ] **Step 4: Verify analyze + tests still pass**

Run: `flutter analyze` then `flutter test`
Expected: clean and green. (No test exercises the URL strategy; the VM path is unaffected because the call is `kIsWeb`-gated.)

- [ ] **Step 5: Manual smoke on the browser**

Run: `flutter run -d edge`
Verify, in the Edge window that opens:
1. The app boots to the sign-in screen with no console errors.
2. The URL has no `/#/` fragment.
3. After sign-in, navigating between tabs updates the path (`/decks`, `/mastery`, …).
4. Signing out redirects to `/login` (go_router `authRedirect` still fires).

If path-strategy URLs break go_router's redirect logic (e.g. a redirect loop or a blank screen on refresh), **fall back to the default hash strategy**: remove the `usePathUrlStrategy()` call and its import, keep `flutter_web_plugins` out of `pubspec.yaml`, and note in the commit body that clean URLs were deferred. This is an explicitly acceptable outcome (§5.4).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "feat: use clean URLs on the web build"
```

(If the fallback was taken, commit only whatever actually changed with a message that says clean URLs were deferred to hash routing.)

---

## Task 3: Hide mirror-only UI on web

**Files:**
- Modify: `lib/features/decks/application/decks_tab_view.dart`
- Modify: `lib/features/decks/presentation/widgets/offline_toggle.dart`
- Modify: `lib/features/decks/presentation/deck_overview_screen.dart`
- Modify: `lib/features/decks/presentation/deck_library_screen.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing consumed by later tasks. Behavior only: on web, no deck tile ever renders "locked offline", the "Keep available offline" card is absent, the legacy "Update offline copy" menu item and deck-library offline badge never show, and the legacy Settings "Notifications" section is absent.

Existing tests run on the Dart VM where `kIsWeb` is `false`, so every guard below is inert under `flutter test` and no existing test needs changing. Do not add new tests in this task (§8 caps the new-test count at the one in Task 1).

- [ ] **Step 1: `decks_tab_view.dart` — never lock a tile on web**

`lib/features/decks/application/decks_tab_view.dart` already imports
`package:flutter/foundation.dart` (line 1), which exports `kIsWeb`.

In `_group(...)`, the local `tile` helper builds `isLockedOffline`. Change:

```dart
        isLockedOffline: !online && !studiable.contains(d.id),
```

to:

```dart
        // On web there is no local mirror and nothing is ever "studiable
        // offline", so an offline browser would otherwise lock every tile with
        // copy about downloading (spec-web-mvp §5.3). The web build is
        // online-only by design; leave tiles unlocked.
        isLockedOffline: !kIsWeb && !online && !studiable.contains(d.id),
```

- [ ] **Step 2: `offline_toggle.dart` — render nothing on web**

`lib/features/decks/presentation/widgets/offline_toggle.dart` — add the import:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
```

At the very top of `build`, before `final ids = ...`:

```dart
    // The "keep available offline" pin needs a local mirror, which the web
    // build never has (spec-web-mvp §5.3).
    if (kIsWeb) return const SizedBox.shrink();
```

- [ ] **Step 3: `deck_overview_screen.dart` — suppress the "Update offline copy" menu item on web**

`lib/features/decks/presentation/deck_overview_screen.dart` — add the import:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
```

Change:

```dart
    final canUpdateOffline = pinned.contains(widget.deckId) && online;
```

to:

```dart
    // Updating a local mirror copy is meaningless with no mirror (web,
    // spec-web-mvp §5.3).
    final canUpdateOffline = !kIsWeb && pinned.contains(widget.deckId) && online;
```

- [ ] **Step 4: `deck_library_screen.dart` — never flag a deck "offline" on web**

`lib/features/decks/presentation/deck_library_screen.dart` — add the import:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
```

Change:

```dart
    final offlineIds =
        ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};
```

to:

```dart
    // No local mirror on web, so no deck is ever "downloaded"
    // (spec-web-mvp §5.3).
    final offlineIds = kIsWeb
        ? const <String>{}
        : ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};
```

- [ ] **Step 5: `settings_screen.dart` — hide the Notifications section on web**

`lib/features/settings/presentation/settings_screen.dart` — add the import:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
```

Wrap the "Notifications" section header, the `SwitchListTile`, and its trailing
`Divider` in a spread guarded by `!kIsWeb`. Change:

```dart
          const _SectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Study reminders'),
            subtitle: const Text(
              'Nudge me a few hours after I leave cards unfinished or parked.',
            ),
            value: remindersEnabled.asData?.value ?? true,
            onChanged: remindersEnabled.isLoading
                ? null
                : (value) => ref
                    .read(notificationsEnabledProvider.notifier)
                    .setEnabled(value),
          ),
          const Divider(),

```

to:

```dart
          // Local notifications cannot fire from a hosted web page
          // (spec-web-mvp §5.3), so the whole section is absent on web.
          if (!kIsWeb) ...[
            const _SectionHeader('Notifications'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Study reminders'),
              subtitle: const Text(
                'Nudge me a few hours after I leave cards unfinished or parked.',
              ),
              value: remindersEnabled.asData?.value ?? true,
              onChanged: remindersEnabled.isLoading
                  ? null
                  : (value) => ref
                      .read(notificationsEnabledProvider.notifier)
                      .setEnabled(value),
            ),
            const Divider(),
          ],

```

If the analyzer then flags `remindersEnabled` as unused on some path, leave it —
it is still referenced inside the guarded spread, so it stays used. Do not
remove the `final remindersEnabled = ...` line.

- [ ] **Step 6: Analyze + full test suite**

Run: `flutter analyze` then `flutter test`
Expected: clean and green — every existing decks / settings test still passes
because `kIsWeb` is `false` under the VM.

- [ ] **Step 7: Commit**

```bash
git add lib/features/decks/application/decks_tab_view.dart lib/features/decks/presentation/widgets/offline_toggle.dart lib/features/decks/presentation/deck_overview_screen.dart lib/features/decks/presentation/deck_library_screen.dart lib/features/settings/presentation/settings_screen.dart
git commit -m "feat: hide mirror-only UI on the web build"
```

---

## Task 4: `web/` metadata

**Files:**
- Modify: `web/index.html`
- Modify: `web/manifest.json`

**Interfaces:** none — static asset edits only.

- [ ] **Step 1: Edit `web/index.html`**

- `<meta name="description" content="A new Flutter project.">` →
  `<meta name="description" content="OpenRecall — a multi-modal active-recall study app.">`
- `<meta name="apple-mobile-web-app-title" content="open_recall">` →
  `<meta name="apple-mobile-web-app-title" content="OpenRecall">`
- `<title>open_recall</title>` → `<title>OpenRecall</title>`

Leave `<base href="$FLUTTER_BASE_HREF">`, the bootstrap script, and the icon
links untouched.

- [ ] **Step 2: Edit `web/manifest.json`**

- `"name": "open_recall"` → `"name": "OpenRecall"`
- `"short_name": "open_recall"` → `"short_name": "OpenRecall"`
- `"description": "A new Flutter project."` →
  `"description": "OpenRecall — a multi-modal active-recall study app."`
- `"background_color": "#0175C2"` → `"background_color": "#121212"`
- `"theme_color": "#0175C2"` → `"theme_color": "#121212"`

(`#121212` is the app's dark-mode background — `AppTokens.dark.background` in
`lib/theme/app_tokens.dart` — so the initial load flash is minimized.)

Leave `start_url`, `display`, `orientation`, `prefer_related_applications`, and
`icons` untouched. No custom loading spinner (§5.5).

- [ ] **Step 3: Sanity-build the web bundle**

Run: `flutter build web`
Expected: build succeeds, `build/web/` is produced, no errors. (This is a
`--debug`-equivalent sanity build; the release build and hosting are Phase 2.)

- [ ] **Step 4: Commit**

```bash
git add web/index.html web/manifest.json
git commit -m "feat: set web app metadata"
```

---

## Task 5: Commit the Phase 0 groundwork and finalize

The `web/` directory, the existing `lib/main.dart` guards, `.metadata`,
`analysis_options.yaml`, and `pubspec.lock` are on disk from the spike but were
never committed. Tasks 1–4 committed the files they each touched; this task
commits the remaining spike files and runs the final gate.

**Files:**
- Commit: `web/` (everything not already committed in Task 4), `lib/main.dart`
  (the `!kIsWeb` guards from the spike — note Task 2 already committed the
  `usePathUrlStrategy` change on top), `.metadata`, `analysis_options.yaml`,
  `pubspec.lock` (if not already swept up by Task 2).

- [ ] **Step 1: Confirm what is left uncommitted**

Run: `git status --porcelain`
Expected: `web/` files (favicon, icons/, `flutter_bootstrap.js` is generated —
only the source `web/` tree is tracked), `.metadata`, `analysis_options.yaml`.
`lib/main.dart` should already be fully committed (Task 2). `docs/codebase-guide/`
should still be listed as untracked — **do not commit it**.

- [ ] **Step 2: Full gate**

Run: `flutter analyze` then `flutter test` then `flutter build web`
Expected: analysis clean, all tests green, web build succeeds.

- [ ] **Step 3: Stage the groundwork explicitly and commit**

```bash
git add web/ .metadata analysis_options.yaml
git add lib/main.dart pubspec.lock
git commit -m "feat: generate the web build target"
```

- [ ] **Step 4: Verify the branch is clean of stray changes**

Run: `git status`
Expected: only `docs/codebase-guide/` remains untracked. Nothing else pending.

---

## Self-Review

**Spec coverage (Phase 1 / §9 bullets):**

| Phase 1 bullet | Task |
|---|---|
| `kIsWeb` guards finalised (§5.1) | Already on disk (spike); committed in Task 5. `usePathUrlStrategy` half of §5.4 in Task 2. |
| `WebAppFrame` + widget test (§5.2, §8) | Task 1 |
| Hide mirror-only UI (§5.3) | Task 3 (live `DeckGridTile` lock + legacy `OfflineToggle`, `DeckOverviewScreen`, `DeckLibraryScreen`, `SettingsScreen`) |
| `usePathUrlStrategy` (§5.4) | Task 2 |
| `web/` metadata edits (§5.5) | Task 4 |
| `flutter analyze` clean, `flutter test` green | Every task ends on this gate; Task 5 is the final gate |
| Commit | Per-task conventional commits; the spec's single `feat: add web build target` is split into readable commits, all on `main` |

**Notes on spec items deliberately not actioned here:**
- §5.1 `.env` served as a public asset — no code change, already in `flutter: assets:` and loads on web. Documented risk, accepted.
- §5.3 `SyncStatusChip` / `OfflineBanner` — kept. With `appDatabaseProvider == null` the pending count is always 0, so `SyncStatusChip` returns `SizedBox.shrink()` while online and only ever shows an accurate bare "offline" state; `OfflineBanner` likewise only shows when the browser is genuinely offline. Both are correct browser-offline indicators, not mirror-only noise.
- §5.3 Profile sign-out dialog "unsynced work" warning — `pendingSyncProvider` resolves to `false` on web (its `isNoop` short-circuit), so the dialog already takes the no-warning branch. No change; the copy reads correctly.
- §5.6 renderer — default CanvasKit, no `--wasm`. Nothing to change; just don't pass the flag.
- §7 hosting, `_redirects`, Supabase URL allow-list — Phase 2.
- §8 manual smoke checklist, cross-browser pass — Phase 3.

**Placeholder scan:** none — every code step contains the literal before/after text.

**Type consistency:** `WebAppFrame({required Widget child, bool enabled})`,
`kWebFrameBreakpoint`, `kWebFrameContentWidth` are used identically in the widget,
the test, and the `app.dart` wiring. `kIsWeb` comes from
`package:flutter/foundation.dart` in every file that gains a guard.

**Scope check:** single focused plan — one delivery target, ~10 files, no
subsystem decomposition needed.
