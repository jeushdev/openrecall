# OpenRecall web build — known issues & limitations

Applies to the hosted web build at **https://open-recall.pages.dev**.
Source of the design decisions: `docs/spec-web-mvp.md` (§4, §10).

The web build is the same Flutter app and the same Supabase project as the
Android APK — a second delivery channel, not a separate product. It is
**phone-first and online-only** by design.

## Cross-browser status (Phase 3 smoke)

| Browser | Status | Notes |
|---|---|---|
| Brave (desktop, Chromium) | ✅ Verified | Full smoke checklist (`docs/spec-web-mvp.md` §8) passed. |
| Chrome / Edge (desktop, Chromium) | ✅ Assumed good | Same engine as Brave; not separately re-run. |
| Firefox (desktop) | ⚠️ Not tested | No blocker expected; run before relying on it. |
| Safari / iOS (iPhone) | ⚠️ Fix applied, unverified | Zoom-lock defect (issue 7) — a viewport fix is in `web/index.html`; needs re-testing on an iPhone. |

## Limitations carried by this release

1. **Mid-session write-loss window.** There is no device-local mirror on
   web, so a connectivity drop or a tab close can lose the last unsynced
   rating(s) of a study session. Mitigated by server-side mastery guarding
   (`updateCardMasteryGuarded`) and the ability to re-run the session. This
   is the one real regression versus the Android build.

2. **No cross-session offline.** Closing the tab with no connectivity and
   reopening later offline gives an unusable app, the same as any online web
   app. Downloaded-deck / "keep available offline" controls are hidden on
   web because they would do nothing.

3. **No study reminders.** Local notifications cannot fire from a plain
   hosted page. The reminders toggle is hidden from Settings on web.

4. **Not installable.** No PWA polish beyond Flutter's generated default —
   no service worker, no offline app shell, no "add to home screen"
   treatment.

5. **First load pulls CanvasKit (~1.5 MB)** plus the app bundle. It is
   CDN-cached afterward, so only the first visit on a fresh cache is slow.

6. **No responsive desktop layout.** On a viewport wider than 600 logical
   px the app renders in a centered 430 px phone-width frame with neutral
   gutters, not a reflowed desktop UI. This is intentional
   (`docs/spec-web-mvp.md` §1).

7. **Safari / iOS zoom-lock (fix applied, needs iPhone verification).**
   Symptom: after signing in, when the deck list loads, the page is zoomed
   in and cannot be pinched back out. Root cause: the Flutter web engine
   injects its own `<meta name="viewport" … maximum-scale=5.0>` at startup
   (and deletes any we declare in `web/index.html`); iOS Safari then
   auto-zooms into the sub-16 px login inputs on focus and never restores,
   and Flutter's gesture layer swallows the pinch that would recover.
   **Fix:** `web/index.html` installs a `MutationObserver` that re-pins the
   viewport to `maximum-scale=1.0, user-scalable=no` every time the engine
   rewrites it, so Safari never auto-zooms. Trade-off: deliberate
   pinch-zoom is disabled on all browsers (iOS's system-level accessibility
   Zoom is unaffected). This is acceptable for an app port and matches
   native-app behaviour. Verify on a real iPhone before closing this out —
   there is no Safari on the dev machine. Safari/iOS remains best-effort and
   not a release gate (`docs/spec-web-mvp.md` §10 item 6).

## Not a limitation, just noted

- `.env` is served as a public static asset on web. It contains only
  `SUPABASE_URL` and the anon/publishable key — both already ship in the
  Android APK and are safe by design under row-level security. Do not put
  anything else in `.env`.
