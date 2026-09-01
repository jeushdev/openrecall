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
| Safari / iOS (iPhone) | ❌ Known defect | Page renders zoomed in and cannot be pinched back out — see issue 7 below. |

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

7. **Safari / iOS renders zoomed in.** On iPhone Safari the app loads
   magnified and the user cannot pinch-zoom back out to a usable size.
   Root cause: the Flutter web engine injects its own
   `<meta name="viewport" … maximum-scale=5.0>` at startup (and removes any
   we set in `web/index.html`), and iOS Safari auto-zooms into the
   sub-16 px login inputs without zooming back out; Flutter's gesture layer
   then swallows the pinch gesture that would recover. Safari/iOS is
   best-effort for this release (`docs/spec-web-mvp.md` §10 item 6) and iOS
   users currently have no other way in, since the APK is Android-only.
   Tracked for a follow-up fix (a viewport `MutationObserver` in
   `web/index.html`).

## Not a limitation, just noted

- `.env` is served as a public static asset on web. It contains only
  `SUPABASE_URL` and the anon/publishable key — both already ship in the
  Android APK and are safe by design under row-level security. Do not put
  anything else in `.env`.
