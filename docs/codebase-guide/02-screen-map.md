# 02 — Screen map (the lookup table)

Every screen in the app. For each: its **route**, its **file**, the
**sub-widgets** it's built from, the **providers** that feed it data, where it
**navigates**, and its **tests**.

All paths are relative to the repo root and verified to exist. Paths under
`presentation/widgets/` are relative to the screen's own feature folder unless
otherwise noted.

Route constants live in `lib/routing/app_routes.dart`; the route→widget table is
`lib/routing/app_router.dart`.

---

## The shell (the four bottom-nav tabs)

Wrapper: **`lib/routing/scaffold_with_nav_bar.dart`** — holds the four tab
branches in a `Stack`, slides between them (240ms), and renders the
`OfflineBanner` strip above them. The bottom bar is
**`lib/routing/glass_bottom_nav_bar.dart`** — the floating glass pill with four
icons + a centre **+** button. The **+** opens `CreateMenuSheet.show(context)`
(`lib/features/decks/presentation/widgets/create_menu_sheet.dart`), a bottom
sheet offering "New course" (`/course-creator`) and "New deck" (`/deck-creator`).

To change the tab icons, order, or the nav bar's look → `glass_bottom_nav_bar.dart`.
To change the slide animation or the offline strip placement → `scaffold_with_nav_bar.dart`.

---

## Decks tab — `/decks` (the home screen)

| | |
|---|---|
| **File** | `lib/features/decks/presentation/decks_tab_screen.dart` |
| **What it is** | "Decks" header + `SyncStatusChip`, then an accordion of collapsible **course** sections. Each expanded section shows a 2-column grid of deck tiles. |
| **Sub-widgets** | In-file: `_Accordion`, `_CourseSection`, `_CourseHeader`, `_CourseEditSheet`, `_AccentPicker`, `_DecksError`. External: `widgets/deck_grid.dart`, `widgets/deck_grid_tile.dart`, `widgets/sync_status_chip.dart`, `widgets/deck_badge.dart`, `widgets/create_deck_tile.dart`. |
| **Providers** | `decksTabViewProvider` (the accordion model — course groups with their decks; cache-first, degrades to local mirror offline), `expandedCoursesProvider` (which sections are open, per-device), `courseControllerProvider` (edit/delete course, for the ⋮ menu), `tabOrderProvider` + `TabOrderController` (drag-to-reorder). Defined in `lib/features/decks/application/decks_tab_view.dart`. |
| **Navigates to** | Deck tile tap → `/deck/:deckId` (deck detail). |
| **Tests** | `test/features/decks/decks_tab_screen_test.dart`, `decks_tab_view_test.dart`, `deck_grid_tile_test.dart`, `tab_order_controller_test.dart` |

## Mastery tab — `/mastery`

| | |
|---|---|
| **File** | `lib/features/stats/presentation/mastery_tab_screen.dart` |
| **What it is** | Stacked read-only sections, coarsest → finest: overall mastery card → per-course rollup strip → per-deck "completions" list → recent-activity feed. **No queries in this file** — every value comes from an aggregation provider. |
| **Sub-widgets** | In-file: `_AsyncSection`, `_AsyncSection2`, `_SectionLoading`, `_SectionError`. External (all under `lib/ui/mastery/`): `overall_mastery_card.dart`, `course_rollup_strip.dart`, `deck_completions_section.dart`, `activity_feed_section.dart`, `mastery_section_header.dart`. |
| **Providers** (all in `lib/features/stats/application/stats_providers.dart`) | `overallMasteryProvider`, `courseSummariesProvider`, `deckRunThroughsProvider`, `recentActivityProvider`, plus `decksProvider`. |
| **Tests** | `test/features/stats/mastery_tab_screen_test.dart`, `activity_feed_section_test.dart`, and the pure-logic tests `overall_mastery_test.dart`, `course_summary_test.dart`, `deck_completion_test.dart`, `activity_feed_test.dart` |

## Profile tab — `/profile`

| | |
|---|---|
| **File** | `lib/ui/profile/profile_tab_screen.dart` |
| **What it is** | Identity header (avatar + email) → streak/mastery stat row → "Study habits" metrics block → placeholder Account/Subscription card → outlined "Sign out" button. |
| **Sub-widgets** (all `lib/ui/profile/`) | `profile_identity_header.dart`, `profile_stats_row.dart`, `profile_stat_block.dart`, `profile_metrics_section.dart`, `account_rows_card.dart` (the "Coming soon" placeholder rows), `sign_out_button.dart`, `sign_out_dialog.dart`. |
| **Providers** | `userIdentityProvider`, `currentStreakProvider` (`lib/features/profile/application/profile_providers.dart`); `studyMetricsProvider`, `overallMasteryProvider` (`lib/features/stats/application/stats_providers.dart`); `accountActionsProvider` (sign-out, `lib/features/settings/application/settings_providers.dart`). |
| **Tests** | `test/ui/profile/profile_tab_screen_test.dart`, `profile_metrics_section_test.dart`; logic: `test/features/stats/streak_test.dart`, `longest_streak_test.dart`, `study_metrics_test.dart` |

## Settings tab — `/settings`

| | |
|---|---|
| **File** | `lib/ui/settings/settings_tab_screen.dart` |
| **What it is** | Collapsible sections: **Appearance** (theme: System/Light/Dark), **Study appearance** (card transition, card text size — segmented toggles), **Feynman mode** (shows last-used timer, info only), **General** (feedback link, about/version). |
| **Sub-widgets** | In-file: `_AppearanceRow`, `_LinkRow`, `_InfoRow`. External (`lib/ui/settings/`): `collapsible_settings_section.dart`, `settings_segmented_control.dart`. |
| **Providers** (mostly `lib/features/settings/application/settings_providers.dart`) | `themeModeProvider`, `studyAppearanceProvider`, `settingsSectionsExpansionProvider`, `appVersionProvider`, `notificationsEnabledProvider`, `lastFeynmanTimerProvider` (`lib/features/study/application/feynman_timer_providers.dart`). |
| **Persistence** | All toggles persist to `SharedPreferences` via small store classes in `lib/features/settings/data/` (`theme_mode_preference.dart`, `study_appearance_preferences.dart`, `notification_preferences.dart`). |
| **Tests** | `test/ui/settings/settings_tab_screen_test.dart`, `collapsible_settings_section_test.dart`, `settings_sections_reset_test.dart`; `test/features/settings/*` |

> There is also an older **`lib/features/settings/presentation/settings_screen.dart`**
> (`SettingsScreen`) plus `widgets/delete_account_dialog.dart`. It holds the
> **delete-account flow** (via a Supabase Edge Function —
> `lib/features/settings/data/supabase_account_repository.dart` →
> `supabase/functions/delete-account/`). **`SettingsScreen` is not registered in
> `app_router.dart`** — it's currently a dead end (see "Dead ends" below), so
> delete-account is unreachable from the UI right now. If you want it back, wire
> `SettingsScreen` (or move its delete flow into
> `lib/ui/settings/settings_tab_screen.dart`) and add a route. The
> `accountActionsProvider.deleteAccount()` call and the Edge Function still
> work.

---

## Auth screens (outside the shell, signed-out only)

| Screen | Route | File |
|---|---|---|
| Splash | `/` | `lib/features/splash/presentation/splash_screen.dart` — a passive frame; `authRedirect` immediately resolves `/` to `/login` or `/decks`. |
| Login | `/login` | `lib/features/auth/presentation/login_screen.dart` |
| Sign up | `/signup` | `lib/features/auth/presentation/signup_screen.dart` |
| Forgot password | `/forgot-password` | `lib/features/auth/presentation/forgot_password_screen.dart` — send-email only; the reset link opens Supabase's hosted page, there's no in-app new-password screen. |

Shared widgets: `lib/features/auth/presentation/widgets/auth_scaffold.dart`,
`email_password_fields.dart`.
Providers: `lib/features/auth/application/auth_providers.dart` —
`authRepositoryProvider`, `authStateChangesProvider`, `authControllerProvider`.
Validation: `lib/features/auth/domain/auth_validators.dart`; error copy:
`auth_error_messages.dart`.
Tests: `test/features/auth/*`, `test/routing/auth_redirect_test.dart`.

---

## Deck / card management screens (top-level routes, no bottom bar)

### Deck detail — `/deck/:deckId`

| | |
|---|---|
| **File** | `lib/features/decks/presentation/deck_detail_screen.dart` |
| **What it is** | What a deck tile opens. App bar with Import action + ⋮ (Edit deck / Delete deck). Body: the `ModePicker` (Flip / Cloze / Feynman — a mode with no qualifying card is shown greyed), then a "View cards (N)" row. Picking a mode pushes `/study/:deckId` with a `StudySessionArgs`. |
| **Sub-widgets** | In-file: `_AddCardsCta`, `_CardsError`, `_DeckAction` enum. External: `lib/features/study/presentation/widgets/mode_picker.dart`, `widgets/course_selector.dart`. |
| **Providers** | `deckCardsProvider(deckId)`, `decksProvider` (for the name), `decksControllerProvider` (edit/delete). |
| **Key logic** | `availableModes(cards)` from `lib/features/decks/domain/study_mode.dart` decides which mode buttons are live. |
| **Tests** | `test/features/decks/deck_detail_screen_test.dart` |

### Import cards — `/deck/:deckId/import`

| | |
|---|---|
| **File** | `lib/features/decks/presentation/import_cards_screen.dart` (a `ConsumerStatefulWidget` — holds the form controllers) |
| **What it is** | One screen folding **manual single-card entry** (Front / Back / keyword chips / concept toggle → save, clear, refocus, "Card added" snackbar, never pop) and **bulk paste** (the `BulkPastePanel`). |
| **Sub-widgets** | `widgets/bulk_paste_panel.dart`, `widgets/keyword_chips_field.dart`, `widgets/card_fields.dart`. |
| **Providers** | `decksControllerProvider` (the `addCard` / `addCards` actions), `deckCardsProvider` (invalidated after a write). |
| **Key logic** | `lib/features/decks/domain/bulk_paste_parser.dart` (pure parser for the paste box), `lib/features/decks/domain/ai_prompt.dart` (the "Copy AI Prompt" text), `keyword_validator.dart`. |
| **Tests** | `test/features/decks/import_cards_screen_test.dart`, `bulk_paste_parser_test.dart`, `keyword_chips_field_test.dart`, `keyword_validator_test.dart` |

### Card list — `/deck/:deckId/cards`

| | |
|---|---|
| **File** | `lib/features/decks/presentation/card_list_screen.dart` |
| **What it is** | View / edit / delete a deck's cards. Each row is a `CardListItem`; tapping opens `EditCardDialog`. |
| **Sub-widgets** | `widgets/card_list_item.dart`, `widgets/edit_card_dialog.dart` (reuses `card_fields.dart`). |
| **Providers** | `deckCardsProvider(deckId)`, `decksControllerProvider`, `pendingDeletionsProvider` (hides a card while its delete is in flight — `lib/features/decks/application/pending_deletions.dart`). |
| **Tests** | `test/features/decks/card_list_screen_test.dart` |

### Deck creator — `/deck-creator`

| | |
|---|---|
| **File** | `lib/routing/placeholders/deck_creator_screen.dart` *(the `placeholders/` path is historical — this is the real, in-use screen)* |
| **What it is** | Name a deck, optionally pick its course (read-only list — no course creation here). No colour picker (accent lives on the course). |
| **Providers** | `deckCreatorControllerProvider` (`lib/features/decks/application/deck_creator_controller.dart`), `coursesProvider`. |
| **Sub-widgets** | `lib/features/decks/presentation/widgets/course_selector.dart`. |
| **Tests** | `test/routing/deck_creator_screen_test.dart` |

### Course creator — `/course-creator`

| | |
|---|---|
| **File** | `lib/features/courses/presentation/course_creator_screen.dart` |
| **What it is** | Name a course + pick one of **eight named accent swatches** (never a hex field). On success pops back to Decks. |
| **Providers** | `courseControllerProvider` (`lib/features/courses/application/course_providers.dart`). |
| **The eight accent keys** | `slate, red, amber, green, teal, blue, violet, pink` — listed in this file and resolved to colours via `AppTokens.accent(key)`. |
| **Tests** | `test/features/courses/course_creator_screen_test.dart`, `course_providers_test.dart` |

---

## Study session — `/study/:deckId`

**File: `lib/features/study/presentation/study_session_screen.dart`.** This one
screen is a small state machine that hosts the mode picker, the Feynman timer
picker, the active card loop (all three modes), the park prompt, and the
summary. **It has its own guide: `04-study-engine.md`.** Don't edit it from this
table alone.

---

## Reusable widget → file (reverse index)

When you can see a component on screen and want its file:

### Decks feature — `lib/features/decks/presentation/widgets/`
| You see | File |
|---|---|
| A square deck tile in the grid (with the "stacked" depth behind it) | `deck_grid_tile.dart` |
| The 2-column grid itself | `deck_grid.dart` |
| The card-count badge under a tile name | `deck_badge.dart` |
| The dashed "＋ Create" cell at the end of the grid | `create_deck_tile.dart` |
| The quiet sync-status chip (top-right of Decks) | `sync_status_chip.dart` |
| The + bottom sheet (New course / New deck) | `create_menu_sheet.dart` |
| The "name your deck" dialog | `create_deck_dialog.dart` |
| The row of course chips (deck creator) | `course_selector.dart` |
| The Front/Back/keywords/concept field set | `card_fields.dart` |
| The keyword chip input | `keyword_chips_field.dart` |
| The thin mastery progress bar + % | `mastery_bar.dart` |
| The "Keep available offline" switch | `offline_toggle.dart` |
| A card row in the card list | `card_list_item.dart` |
| The edit-card dialog | `edit_card_dialog.dart` |
| The bulk-paste panel with live preview | `bulk_paste_panel.dart` |
| *(legacy, see below)* the deck-overview mode buttons | `mode_selector.dart` |
| *(legacy)* a Deck Library list row | `deck_tile.dart` |
| *(legacy)* session-length preset toggle | `session_length_selector.dart` |

### Study feature — `lib/features/study/presentation/widgets/`
| You see | File |
|---|---|
| The Flip card (tap to flip) | `flip_card.dart` |
| The Cloze card (blanked keywords, type-in) | `cloze_type_card.dart` |
| The Feynman card (prompt, no input, self-checkoff) | `feynman_card_view.dart` |
| The "Reveal reference" overlay (Feynman) | `feynman_reference_dialog.dart` |
| The Feynman timer preset picker | `feynman_timer_picker.dart` |
| The 4-button rating row (Unfamiliar→Mastered) | `rating_row.dart` |
| The pre-session "pick a mode" screen | `mode_picker.dart` |
| The "park this card?" dialog | `park_prompt_dialog.dart` |
| The end-of-session summary | `session_summary_view.dart` |
| The layered "stacked deck" behind the active card | `stacked_deck.dart` |
| The 2px progress bar at the top of a session | `study_progress_bar.dart` |

### Mastery tab — `lib/ui/mastery/`
| You see | File |
|---|---|
| The big % card at the top | `overall_mastery_card.dart` |
| The horizontal strip of course chips | `course_rollup_strip.dart` |
| The "Deck completions" ×N list | `deck_completions_section.dart` |
| The "Recent activity" feed | `activity_feed_section.dart` |
| A section title ("Deck completions" / "Recent activity") | `mastery_section_header.dart` |

### Profile tab — `lib/ui/profile/`
| You see | File |
|---|---|
| Avatar circle + email | `profile_identity_header.dart` |
| The streak + mastery two-tile row | `profile_stats_row.dart` |
| One stat tile (label / big value / caption) | `profile_stat_block.dart` |
| The "Study habits" block | `profile_metrics_section.dart` |
| The "Account" / "Subscription — Coming soon" card | `account_rows_card.dart` |
| The red outlined "Sign out" button | `sign_out_button.dart` |
| The sign-out confirmation (warns about unsynced work) | `sign_out_dialog.dart` |

### Settings tab — `lib/ui/settings/`
| You see | File |
|---|---|
| A collapsible titled section | `collapsible_settings_section.dart` |
| A segmented pill selector (System/Light/Dark etc.) | `settings_segmented_control.dart` |

### App-wide — `lib/core/ui/`
| You see | File |
|---|---|
| The hairline "You're offline" strip above the tabs | `offline_banner.dart` |
| (the global SnackBar plumbing) | `app_messenger.dart` |

---

## Dead ends — files that compile but are NOT reachable

Do **not** waste time editing these expecting to see a change:

- **`lib/features/decks/presentation/deck_library_screen.dart`** — the old
  pre-revamp deck list, replaced by `decks_tab_screen.dart`.
- **`lib/features/decks/presentation/deck_overview_screen.dart`** — the old
  pre-revamp per-deck overview, replaced by `deck_detail_screen.dart`.
- **`lib/features/settings/presentation/settings_screen.dart`** — the old
  settings screen, replaced by `lib/ui/settings/settings_tab_screen.dart`. Still
  the only home of the delete-account flow (see the note under Settings above).

`lib/routing/app_routes.dart` says so itself, in its comment block ending
`static const String deckOverviewName = 'deck-overview';` — *"no route is
registered for it, so a `pushNamed` would throw at runtime."* These were the
milestone U4/U5 screens, replaced by the deck-detail flow in the ui-spec-v2
revamp but never deleted. Their widgets under `widgets/` marked *(legacy)* above
are only referenced by these dead screens.
