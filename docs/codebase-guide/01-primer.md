# 01 — Flutter primer, taught from this repo

You can read code. This file fills the gap between "I can read Dart" and "I can
read *this app's* files without guessing." Every concept below is illustrated
with a real file you can open right now.

---

## 1. Dart, the 30-second version

- `final x = ...` — a variable that's assigned once. `const x = ...` — a
  compile-time constant. `var x` — mutable. Most things here are `final`.
- `Type? x` — the `?` means "can be null." `x?.foo` calls `foo` only if `x`
  isn't null. `x ?? y` means "x, or y if x is null." `x!` means "I promise this
  isn't null" (crashes if it is).
- `class Foo { Foo(this.a); final int a; }` — constructor shorthand: `this.a`
  in the parameter list assigns the field.
- `switch (x) { Foo.a => 1, Foo.b => 2 }` — a switch *expression* that returns
  a value. Used everywhere for enum → value mappings.
- `abstract final class AppRoutes { ... static const ... }` — this repo's idiom
  for "a namespace of constants, never instantiated." See
  `lib/routing/app_routes.dart`.
- `@immutable` above a class — a promise that all its fields are `final`. Common
  on model classes.

---

## 2. Widgets and `build()`

**Everything on screen is a widget.** A widget is a class with a `build()`
method that returns more widgets. The tree of widgets *is* the UI.

**Worked example — open `lib/ui/profile/profile_tab_screen.dart` (68 lines).**

```dart
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final email = ref.watch(userIdentityProvider).email;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text('Profile', style: TextStyle(fontSize: 28, ...)),
            const SizedBox(height: 20),
            ProfileIdentityHeader(email: email),
            const SizedBox(height: 24),
            const ProfileStatsRow(),
            ...
          ],
        ),
      ),
    );
  }
}
```

The vocabulary you'll see on every screen:

| Widget | What it does |
|---|---|
| `Scaffold` | The page frame. `backgroundColor`, `body`, sometimes `appBar`. |
| `SafeArea` | Insets its child clear of the notch / status bar / home indicator. `bottom: false` = don't inset the bottom (the floating nav bar handles that). |
| `ListView` / `ListView.separated` | A scrolling column. `children:` for a fixed list; `.builder` / `.separated` for a long/dynamic one. |
| `Column` / `Row` | Non-scrolling vertical / horizontal stack. `crossAxisAlignment: CrossAxisAlignment.start` = left-align. |
| `SizedBox(height: 20)` | **This is how spacing is done** — an empty box between items. There is no CSS margin. |
| `Padding(padding: EdgeInsets...)` | Space *inside* around a child. `EdgeInsets.fromLTRB(left, top, right, bottom)` / `.all(16)` / `.symmetric(horizontal: 16)`. |
| `Text('...', style: TextStyle(...))` | Text. |
| `Expanded` / `Spacer` | Inside a Row/Column: "take all remaining space." |
| `Center` | Centres its child. |
| `Container` | A box with optional colour, border, padding, radius. The app uses solid offset `Container`s to fake depth — **`BoxShadow` is banned** (ui-spec-v1 §3.3). |
| `IconButton` / `TextButton` / `OutlinedButton` | Tappable controls. |
| `GestureDetector` / `InkWell` | Wrap anything to make it tappable (`onTap:`). |

To **change a screen's layout or copy**, you edit the widget tree in its
`build()` method. Change a string in a `Text(...)`, add or remove a child in a
`Column`, change a `SizedBox` height.

---

## 3. StatelessWidget vs StatefulWidget vs ConsumerWidget

- **`StatelessWidget`** — no internal mutable state. Rebuilds only when its
  inputs change. Most small sub-widgets (`_CourseHeader`, `ProfileStatBlock`).
- **`StatefulWidget`** — has a companion `State` class holding mutable fields
  (a `TextEditingController`, a bool toggled by the user, an animation).
  Recognise it by the `class Foo extends StatefulWidget` +
  `class _FooState extends State<Foo>` pair. Example:
  `lib/features/decks/presentation/import_cards_screen.dart` (it holds text
  controllers and a `_keywords` list).
- **`ConsumerWidget` / `ConsumerStatefulWidget`** — the Riverpod versions.
  `build()` gets an extra `WidgetRef ref` parameter, which is how the widget
  reads app state. **Most screens in this app are `ConsumerWidget`.**

The `const` before a widget constructor (`const SizedBox(...)`,
`const ProfileStatsRow()`) is a performance hint: "this widget never changes,
don't rebuild it." Add it wherever the analyzer suggests.

---

## 4. Riverpod — app state — in three sentences

1. A **provider** is a named, globally-accessible box that holds a value (or
   knows how to compute one). It's declared at the top level of a file:
   `final decksProvider = FutureProvider<...>((ref) => ...);`
2. `ref.watch(someProvider)` reads the current value **and** subscribes — when
   the value changes, this widget's `build()` re-runs automatically.
3. `ref.read(someProvider.notifier)` gets the *controller* object so you can
   call a method on it (`.create(...)`, `.rate(...)`); `ref.read(someProvider)`
   reads once without subscribing (for one-off reads in callbacks).

**Worked example — `lib/ui/settings/settings_tab_screen.dart` lines 29–41.**
The Settings screen watches five providers in a row:

```dart
final themeMode = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
final themeController = ref.read(themeModeProvider.notifier);
final appearance = ref.watch(studyAppearanceProvider).asData?.value ?? StudyAppearance.defaults;
final controller = ref.read(studyAppearanceProvider.notifier);
final lastFeynman = ref.watch(lastFeynmanTimerProvider);
```

When the user taps a theme segment, the code calls
`themeController.setThemeMode(ThemeMode.dark)`; that updates `themeModeProvider`;
every widget that `ref.watch`es it (this screen, and `app.dart` which sets
`MaterialApp.themeMode`) rebuilds. No manual wiring.

### `ref.listen` — side effects, not rebuilds

`ref.listen(someProvider, (prev, next) { ... })` runs a callback when a provider
changes **without** rebuilding. Used to show SnackBars on error — see the top of
almost every screen's `build()`:

```dart
ref.listen(decksControllerProvider, (_, next) {
  if (next case AsyncError(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }
});
```

---

## 5. `AsyncValue` — the loading / error / data box

Anything fetched asynchronously (from Supabase, from SQLite) comes wrapped in an
`AsyncValue<T>`, which is always in one of three states. Two ways to unwrap it:

**`.when(...)`** — handle all three explicitly (used when the screen shows a
real spinner / error page):

```dart
final cards = ref.watch(deckCardsProvider(deckId));
return cards.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (err, _) => _CardsError(onRetry: () => ref.invalidate(deckCardsProvider(deckId))),
  data: (list) => ListView(children: [...]),
);
```

**`.asData?.value ?? fallback`** — "give me the data if it's loaded, otherwise
this default" (used for settings toggles, which should always render *something*
rather than a spinner):

```dart
final themeMode = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
```

**`ref.invalidate(someProvider)`** means "throw away the cached value and
re-fetch." That's what every "Retry" button and every post-write refresh does.

---

## 6. The provider *kinds* used in this app

| Kind | Means | Example |
|---|---|---|
| `Provider<T>` | A plain value, computed once. Usually a repository or a service. | `deckRepositoryProvider`, `authRepositoryProvider` |
| `FutureProvider<T>` | An async read. Exposes an `AsyncValue<T>`. | `decksProvider`, `coursesProvider` |
| `FutureProvider.family<T, Arg>` | A `FutureProvider` parameterised by an argument. You call it like a function: `deckCardsProvider(deckId)`. | `deckCardsProvider`, `preSessionCardsProvider` |
| `StreamProvider<T>` | Like `FutureProvider` but for a stream of values. | `authStateChangesProvider` |
| `NotifierProvider<C, T>` | A controller class `C` (with methods you call) that manages a value `T`. | `tabOrderProvider` |
| `AsyncNotifierProvider<C, T>` | Same, but async-aware — its state is an `AsyncValue<T>`. The "…Controller" providers that track an in-flight action. | `decksControllerProvider`, `courseControllerProvider`, `authControllerProvider`, `sessionControllerProvider` |

**The "…Controller" pattern, repeated across every feature:** a controller
provider that holds *no data of its own* — `AsyncNotifier<void>` — and only
tracks whether the most recent action (create deck, sign in, delete card) is
running / succeeded / failed. `isLoading` disables the button;
`AsyncError` feeds a SnackBar via `ref.listen`. Search a feature for
`extends AsyncNotifier<void>` to find it.

---

## 7. go_router — navigation

- **Route paths and names** are constants in `lib/routing/app_routes.dart`
  (`AppRoutes.deckDetailPath` = `'/deck/:deckId'`, `AppRoutes.deckDetailName`
  = `'deck-detail'`).
- **The route table** — which path builds which screen widget — is
  `lib/routing/app_router.dart`.
- **To navigate**, a screen calls
  `context.pushNamed(AppRoutes.deckDetailName, pathParameters: {'deckId': id})`
  (push = new screen on top, back button returns) or `context.goNamed(...)`
  (replace). Some pass data via `extra:` (e.g. the study route gets a
  `StudySessionArgs` carrying the chosen mode).

### The shell — why the four tabs are special

The router has one `StatefulShellRoute` with **four branches**: `/decks`,
`/mastery`, `/profile`, `/settings`. This structure means:

- Each tab keeps its own scroll position and state when you switch away and
  back.
- The bottom nav bar lives *inside* the shell
  (`lib/routing/scaffold_with_nav_bar.dart` → `glass_bottom_nav_bar.dart`).

Every **other** screen (study session, deck detail, import, card list, the
creators) is a **top-level route outside the shell** — which is exactly why the
bottom nav bar is simply absent there. There's no "hide the nav bar" code; it's
just not in that part of the tree.

### Auth gating

`lib/routing/auth_redirect.dart` is the single rule: signed-out users can only
sit on `/login`, `/signup`, `/forgot-password`; everything else redirects to
`/login`. `lib/routing/go_router_refresh_stream.dart` re-runs that rule whenever
the Supabase session appears or clears, so signing in/out navigates on its own.

---

## 8. Reading conventions specific to this repo

- **`class _SomethingWithLeadingUnderscore`** — file-private. A sub-widget or
  helper used *only* in the file it's declared in. If you see `_CourseHeader` in
  `decks_tab_screen.dart`, it's defined lower in that same file — never
  anywhere else. Search within the file.
- **Doc comments cite spec sections** — `// spec §5`, `// ui-spec-v2 §6.3`,
  `// docs/spec-v3-card-model.md`. Follow these into `docs/` for the *why*.
- **`abstract final class Foo`** — a constants namespace (`AppRoutes`,
  `AppRadii`, `AppBorders`, `AppMotion`, `AppTheme`).
- **`lib/features/<feature>/` vs `lib/ui/<tab>/`** — both hold presentation
  code. Later milestones put new screen widgets under `lib/ui/`; their state
  providers stayed under `lib/features/<feature>/application/`. When hunting for
  a screen, check both. `02-screen-map.md` tells you which is which.
- **`test/` mirrors `lib/`** — the test for `lib/features/decks/domain/card.dart`
  is `test/features/decks/card_test.dart`. Fakes are in `test/support/`.

---

## 9. How to explore safely (with no agent)

1. `flutter test` — confirm green **before** you touch anything.
2. Make the smallest possible change — one string, one number.
3. `flutter analyze` — must be clean (no new warnings).
4. `flutter run`, then press `r` to hot-reload and see it.
5. `flutter test` again — still green?
6. If yes, commit (`git commit`). If a test broke, `git checkout .` to undo and
   read the failing test — it usually tells you exactly what contract you broke.

The test suite is large (~100 files) and fast. It is your safety net. Trust it.
