# Responsive UI layout plan

## Purpose and execution

Correct responsive-layout failures on Android phones while preserving the current UI and functionality. This plan follows a static audit of `lib/`; suspected failures must be reproduced before choosing implementation details. It does not imply that every listed condition has been observed on a device.

Execute one milestone per task, in the order below. Each milestone is a separate reviewable change. Do not automatically proceed to the next milestone. Record the completed scope, validation results, and remaining limitations in the execution log at the end of this document.

Suggested task instruction:

> Execute Milestone N in docs/responsive-layout-ui.md only. Inspect the current code and working-tree changes first, preserve the visual design and functionality, validate the milestone's acceptance criteria, and update its status and execution log. Do not begin another milestone.

## Constraints applying to every milestone

- Preserve colors, fonts, typography roles, dark/light themes, decorative elements, navigation destinations, interactions, feature availability, and content order.
- Change constraints and sizing rather than redesigning screens. Preserve the default appearance where it already fits. Allow content to grow, wrap, or scroll when required.
- Do not change Supabase, database, auth, domain, or business behavior.
- Use standard Flutter layout widgets. Do not add a large responsiveness dependency or device-specific magic-number branches.
- Do not solve overflow by clipping, hiding content, shrinking fonts, or suppressing Android text scaling. Keep intentional truncation for summaries only where the full value remains accessible; essential action labels must remain understandable.
- Preserve intentional deck backing layers, carousel neighbors, and transition effects. Do not interpret those as duplicated data without evidence.
- Do not overwrite unrelated working-tree changes. The audit observed existing edits to `home_tab_screen.dart` and `large_title_scaffold.dart`; inspect the current state rather than assuming those edits are still present or disposable.
- Limit changes to the milestone's scope, directly required shared layout code, and relevant tests. Document any newly discovered dependency instead of silently expanding the task.

## Validation contract

Target logical viewports:

| Width | Height |
| --- | --- |
| 320 | 568 |
| 360 | 640 |
| 360 | 800 |
| 393 | 873 |
| 412 | 915 |
| 480 | 960 |

Use text scales 1.0, 1.3, 1.5, and 2.0 as widget-test coverage, plus Android system font scaling in manual validation where available. Test representative top/bottom system insets and keyboard insets. Do not confuse physical pixels with logical viewport dimensions in tests.

For each milestone:

1. Reproduce its strongest failure with a focused widget test or device inspection before changing the layout.
2. Validate affected widgets at all six widths, and affected full screens at short and tall viewport heights. Include long content and relevant populated, empty, error, and keyboard states.
3. Assert no layout exceptions and verify that important labels, content, and actions remain visible or reachable by scrolling. An absence of RenderFlex errors alone does not prove that content is not clipped or ellipsized.
4. Inspect representative light/dark rendering and default-scale appearance. Use existing fonts and theme tokens.
5. Run relevant existing tests and analysis appropriate to the changed code. Report checks that could not be run; do not claim emulator validation from widget tests alone.

Add regression coverage with each fix. The final testing milestone consolidates coverage rather than deferring all tests until the end.

## Milestone 1 — Bounded, keyboard-aware bottom sheets

**Status:** Complete

**Depends on:** None

### Scope and evidence

- `lib/features/decks/presentation/widgets/create_menu_sheet.dart`: `_CreateMenuSheetState` expands all import targets into non-scrollable columns inside a height-limited modal.
- `lib/features/decks/presentation/decks_tab_screen.dart`: `_CourseEditSheetState` adds keyboard padding around a non-scrollable column.
- `lib/features/decks/presentation/deck_detail_screen.dart`: `_DeckEditSheetState` repeats the same pattern.
- `lib/features/profile/presentation/profile_edit_sheet.dart`: `_ProfileEditSheetState` repeats the same pattern.

### Work

- Establish a small shared sheet layout in the existing common UI area if it usefully serves these callers. Define ownership of available height, safe insets, keyboard insets, and scrolling.
- Make the expanded import targets scroll within the modal's available height without changing selection or navigation behavior.
- Apply the same sizing convention to deck, course, and profile edit sheets. Preserve field order, autofocus, validation, handles, and Save behavior.
- Keep short sheets naturally sized; avoid forcing every sheet to full-screen height.

### Acceptance criteria

- All import targets remain reachable with a large collection and long deck names.
- Course and deck editing works at 320×568 and 360×640 with the keyboard open, including wrapped swatches and validation/error content.
- Profile validation and Save remain reachable with enlarged text and keyboard insets.
- No content overlaps system UI, no double keyboard padding appears, and sheet dismissal/selection behavior is unchanged.

## Milestone 2 — Navigation, collapsing headers, and bottom clearance

**Status:** Not started

**Depends on:** None; execute after Milestone 1 for the recommended priority order.

### Scope and evidence

- `lib/routing/ios_tab_bar.dart`: `IosTabBar` derives height from screen height; `_TabItem` consumes approximately 62 pixels at default scale inside a minimum 64-pixel bar.
- `lib/routing/scaffold_with_nav_bar.dart`: owns the extended body and navigation overlay.
- `lib/ui/common/large_title_scaffold.dart`: fixed expanded height, scaled title, no explicit title/action space policy, and an unused `contentPadding` parameter.
- Home, Decks, History, More, and Settings callers contain independent 120-pixel bottom reservations.

### Work

- Derive navigation minimum height from icon, label, spacing, and text requirements rather than a viewport-height percentage.
- Define expanded/collapsed title sizing and action-space constraints for long greetings and the Decks create/sync actions.
- Centralize the convention for content clearance below the overlay navigation, using actual safe-area/navigation requirements. Distinguish tab screens from standalone screens.
- Resolve the unused `contentPadding` API deliberately: make ownership explicit or remove the misleading parameter and migrate callers. Do not apply existing padding a second time.
- Preserve the current blur, tab order, transitions, header styling, and navigation behavior.

### Acceptance criteria

- Every tab label fits at all target viewports and scales without clipping.
- Long Home greetings and Decks actions do not overlap in expanded, intermediate, or collapsed header states, including visible offline/pending-sync indicators.
- Last content and actions can scroll clear of navigation with representative Android bottom insets.
- Standalone Settings does not reserve nonexistent tab-bar space, and tab screens do not acquire duplicate bottom gaps.

## Milestone 3 — Shared rows and compact selectors

**Status:** Not started

**Depends on:** Milestone 2 for final screen-level clearance and header behavior.

### Scope and evidence

- `lib/ui/common/ios_list.dart`: `IosRow` constrains its title but leaves trailing values/widgets unconstrained.
- `lib/ui/stats/session_log_list.dart`: `_LogRow` places mode, count, and mastery delta into the trailing area.
- `lib/ui/settings/settings_segmented_control.dart`: a fixed 40-pixel container leaves only 32 pixels inside for potentially wrapped labels.
- `lib/features/decks/presentation/widgets/course_selector.dart`: fixed-height chips allow two-line names.

### Work

- Define a shared width-allocation policy for row titles and metadata. Permit a secondary line or other minimal reflow when the current horizontal presentation cannot fit.
- Keep trailing switches, chevrons, values, and custom widgets working for all existing `IosRow` callers.
- Give settings segments and course chips enough height for scaled permitted text lines while preserving selection semantics and horizontal scrolling.
- Inspect related compact controls only where reachable from current screens; do not refactor unused legacy widgets simply because they contain similar constants.

### Acceptance criteria

- History entries with long names, Feynman metadata, large counts, and mastery deltas remain readable at narrow widths.
- Titles are not squeezed into unusable vertical strips by unconstrained metadata.
- Settings labels such as “Fade & slide” and selected long course names fit without being clipped vertically.
- Existing selection, trailing-control interaction, and row tap behavior remain unchanged.

## Milestone 4 — Home content sizing and deck grids

**Status:** Not started

**Depends on:** Milestone 2; retain selector conventions from Milestone 3.

### Scope and evidence

- `lib/features/home/presentation/home_tab_screen.dart`: `_DeckStackState` fixes carousel height at 260 with `viewportFraction: 0.82`; `_DeckCard` adds an inner aspect ratio and an inflexible footer row.
- The same file's `_UnfinishedStrip` reserves 184 pixels even for zero or one session; `_UnfinishedCard` gives the percentage a fixed 34-pixel width.
- `lib/features/decks/presentation/widgets/deck_grid.dart`: always uses two square columns.
- `lib/features/decks/presentation/widgets/deck_grid_tile.dart` and `deck_badge.dart`: title, badge, and offline hint must share the resulting tile height.

### Work

- Establish one coherent carousel sizing strategy based on local width and scaled content requirements. Remove competing sizing assumptions while retaining the carousel and neighboring-card effects.
- Make card count and View Deck fit through appropriate constraints or minimal footer reflow.
- Size the unfinished-session area from displayed content while preserving the existing session limit and empty-state behavior. Allocate percentage width according to content.
- Derive grid tile extent from available width and text needs. Preserve the two-column appearance wherever usable; any necessary fallback must be based on content constraints, not device names or resolution branches.
- Preserve card colors, padding character, typography, rounding, and accent backing layers.

### Acceptance criteria

- Home cards support long course/deck names, large counts, and enlarged text without footer overflow or vertical clipping.
- Zero, one, two, and three unfinished sessions do not reserve empty card slots; percentages remain readable.
- Grid titles, empty badges, populated badges, and offline hints fit at the target widths/scales.
- Deck tapping, carousel paging, course expansion, deck reordering, and the Create tile continue to work.
- Do not broaden this milestone into a sliver/performance rewrite unless a measured layout failure requires it.

## Milestone 5 — Study controls and pre-session layouts

**Status:** Not started

**Depends on:** None at the code level; execute after Milestone 4.

### Scope and evidence

- `lib/features/study/presentation/widgets/rating_row.dart`: four equal-width buttons, fixed gaps, and single-line ellipsis truncate essential labels on narrow screens.
- `lib/features/study/presentation/widgets/feynman_timer_picker.dart`: four fixed-height choices and explanatory text sit in a non-scrollable column.
- `lib/features/study/presentation/widgets/mode_picker.dart`: uses the same centered non-scrollable column convention.
- `lib/features/study/presentation/study_session_screen.dart`: active cards already have a constraint-aware scroll area; preserve this safeguard.

### Work

- Allow rating labels to remain readable through wrapping and content-aware height. Use minimal constraint-driven reflow only when required, preserving order and rating semantics.
- Give timer/mode selection a scroll fallback while retaining centered placement when content fits.
- Verify the revised controls with the existing active-card scroll area, card transitions, and Feynman reveal state.
- Exercise both Android text scaling and the existing card-size preferences. The current scoped card scaler replaces the inherited scaler; do not use that behavior as evidence of Android scaling support or change preference semantics without a separately documented decision.
- Correct any reproduced local header/action constraint issue in the affected study widgets without changing session behavior.

### Acceptance criteria

- All four rating labels are understandable without essential text ellipsis at every target width/scale.
- The timer picker and mode picker remain fully reachable on 320×568 with enlarged text.
- Long Flip/Feynman content remains scrollable; Cloze fields and submit actions remain reachable with the keyboard open.
- Disabled/enabled ratings, swipe gestures, reveal behavior, timers, and card transitions retain their current functionality.

## Milestone 6 — Consolidated Android responsive regression coverage

**Status:** Not started

**Depends on:** Milestones 1–5

### Work

- Consolidate a reusable test harness for logical viewport dimensions, text scaling, insets, and existing theme/provider setup. Reset test view configuration between cases.
- Cover shared primitives across the complete viewport/scale matrix; cover representative full-screen flows using focused combinations of data, keyboard state, and theme.
- Include Home, Decks, History, More/Settings, auth, creator/edit forms, import selection, pre-session choices, active study modes, and session summary.
- Retain functional tests that intentionally use tall surfaces, but add phone-sized cases. Existing oversized test surfaces must not be the sole responsiveness evidence.
- Include geometric/visibility assertions and representative visual inspection, not just `takeException()` checks. Ensure bundled fonts load where text measurement matters.
- Verify intentional carousel neighbors and transition layers do not obscure active controls; do not remove them as a test shortcut.
- Run relevant suites and an Android manual smoke pass where an emulator/device is available. Record environment limitations explicitly.

### Acceptance criteria

- Every high-priority audited root cause has a regression case.
- The six logical viewports and specified scale levels are represented in shared-layout coverage.
- Keyboard, long-content, empty/populated, offline, header-collapse, and both-theme cases have explicit coverage.
- No known unreachable action, layout exception, unintended clipping, or essential-label truncation remains in the exercised flows.
- Any remaining issue is documented with reproduction conditions and scope; the completion record distinguishes automated and manual validation.

## Execution log

Update after each independently executed milestone. Do not mark a milestone complete solely because code was changed.

| Milestone | Date | Changes and validation evidence | Remaining limitations |
| --- | --- | --- | --- |
| 1 | 2026-09-06 | Reproduced the expanded Create Menu failure at 320×568 (999-pixel bottom overflow). Added a shared bounded, keyboard-aware scrolling sheet body and applied it to Create Menu plus course, deck, and profile editing. Import labels now wrap. Added regression coverage for all six viewport sizes at text scales 1.0, 1.3, 1.5, and 2.0, representative safe/keyboard insets, short-sheet sizing, dark theme, long import lists, wrapped course swatches, and reachable Save/validation behavior. All 70 focused tests passed. Full `flutter analyze` completed with no Milestone 1 findings. | No Android target was connected, so the manual Android smoke pass was not run. Full analysis still reports three pre-existing warnings in `home_tab_screen.dart` (unused `style` parameter, `_CardSkeleton`, and `_SectionError`). |
| 2 | — | Not started | — |
| 3 | — | Not started | — |
| 4 | — | Not started | — |
| 5 | — | Not started | — |
| 6 | — | Not started | — |
