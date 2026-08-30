import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../courses/application/course_providers.dart';
import '../../courses/domain/course.dart';
import '../domain/deck.dart';
import 'deck_providers.dart';

/// One deck as the Decks-tab accordion needs it (ui-spec-v2 §5): the deck's
/// name, its card count for the tile badge, and the parent course's accent
/// already resolved to its named key.
@immutable
class DeckTileView {
  const DeckTileView({
    required this.id,
    required this.name,
    required this.cardCount,
    required this.accentKey,
  });

  /// The real `decks.id` — handed straight to `/study/:deckId`.
  final String id;
  final String name;

  /// Total cards in the deck — the tile badge shows `"{n} cards"` (§5).
  final int cardCount;

  /// One of the eight `courses.accent_color` keys, resolved through the deck's
  /// parent course. Falls back to `slate` when the course is unknown.
  final String accentKey;
}

/// One course and the decks under it, as the Decks-tab accordion renders them
/// (ui-spec-v2 §5). Every course the user has gets a group, even with no decks,
/// so a course just created from the + menu is visible immediately.
@immutable
class CourseDeckGroup {
  const CourseDeckGroup({required this.course, required this.decks});

  final Course course;
  final List<DeckTileView> decks;
}

/// How long the Decks tab waits on the deck-list fetch before giving up. The tab
/// is the app's home screen — it must not sit on a spinner forever because
/// Supabase is slow or asleep (same reasoning as the study screen's bound,
/// ui-spec-v1 §2). Overridden short in tests.
final decksLoadTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 6));

/// The deck list for the tab, bounded by [decksLoadTimeoutProvider]. Separate
/// from the app-wide [decksProvider] (which the Mastery tab and stats layer also
/// read) so the timeout only applies here.
final tabDecksProvider = FutureProvider<List<DeckSummary>>((ref) async {
  final timeout = ref.watch(decksLoadTimeoutProvider);
  return ref.watch(deckRepositoryProvider).fetchDecks().timeout(timeout);
});

/// The Decks-tab accordion model (ui-spec-v2 §5): the user's courses ordered by
/// `created_at` ascending — so the default course sorts first — each with its
/// decks.
///
/// Driven by [tabDecksProvider] — its loading / error / empty state is the
/// screen's state. [coursesProvider] is best-effort enrichment: while it loads
/// or if it fails, every deck falls into a single synthetic group so the tab
/// still renders rather than blocking.
final decksTabViewProvider =
    Provider<AsyncValue<List<CourseDeckGroup>>>((ref) {
  final decksAsync = ref.watch(tabDecksProvider);
  final courses =
      ref.watch(coursesProvider).asData?.value ?? const <Course>[];

  return decksAsync.whenData((decks) => _group(decks, courses));
});

/// The group used when the course list hasn't loaded (or is empty): one bucket
/// for every deck, keyed by a stable sentinel id so the expand/collapse
/// persistence still has something to store.
final _syntheticDefaultCourse = Course(
  id: '_default',
  userId: '',
  name: 'Decks',
  accentColor: 'slate',
  isDefault: true,
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2000),
);

List<CourseDeckGroup> _group(List<DeckSummary> decks, List<Course> courses) {
  DeckTileView tile(DeckSummary d, String accentKey) => DeckTileView(
        id: d.id,
        name: d.name,
        cardCount: d.totalCards,
        accentKey: accentKey,
      );

  if (courses.isEmpty) {
    return [
      CourseDeckGroup(
        course: _syntheticDefaultCourse,
        decks: [
          for (final d in decks)
            tile(d, _syntheticDefaultCourse.accentColor),
        ],
      ),
    ];
  }

  final ordered = [...courses]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final byId = {for (final c in ordered) c.id: c};
  final defaultCourse =
      ordered.firstWhere((c) => c.isDefault, orElse: () => ordered.first);

  final buckets = {for (final c in ordered) c.id: <DeckTileView>[]};
  for (final d in decks) {
    final course = byId[d.courseId] ?? defaultCourse;
    buckets[course.id]!.add(tile(d, course.accentColor));
  }

  return [
    for (final c in ordered) CourseDeckGroup(course: c, decks: buckets[c.id]!),
  ];
}

/// Re-runs the deck-list and course fetches (Retry on the error state).
void refreshDecksTab(WidgetRef ref) {
  ref.invalidate(tabDecksProvider);
  ref.invalidate(decksProvider);
  ref.invalidate(coursesProvider);
}

/// Device-local persistence for which Decks-tab course sections are expanded
/// (ui-spec-v2 §5). Per-device UI state, not synced app data — same
/// `SharedPreferences` + injectable-prefs shape as the U8 "Study appearance"
/// store ([StudyAppearancePreferences]).
class DecksAccordionPreferences {
  DecksAccordionPreferences([SharedPreferences? prefs]) : _injected = prefs;

  static const String _key = 'decks_expanded_courses';

  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  /// The course ids the user has expanded, or `null` if they have never toggled
  /// a section — the first-run case, where the screen falls back to "only the
  /// default course open".
  Future<Set<String>?> expandedCourseIds() async {
    final raw = (await _prefs).getStringList(_key);
    return raw?.toSet();
  }

  Future<void> setExpandedCourseIds(Set<String> ids) async {
    await (await _prefs).setStringList(_key, ids.toList());
  }
}

final decksAccordionPreferencesProvider =
    Provider<DecksAccordionPreferences>((ref) => DecksAccordionPreferences());

/// The expanded Decks-tab course sections (ui-spec-v2 §5). `null` until the user
/// first toggles a section; after that the persisted set is authoritative.
/// `build()` swallows a storage failure and returns `null` so the tab always
/// renders (mirrors how the Settings toggles degrade).
final expandedCoursesProvider =
    AsyncNotifierProvider<ExpandedCoursesController, Set<String>?>(
  ExpandedCoursesController.new,
);

class ExpandedCoursesController extends AsyncNotifier<Set<String>?> {
  DecksAccordionPreferences get _prefs =>
      ref.read(decksAccordionPreferencesProvider);

  @override
  Future<Set<String>?> build() async {
    try {
      return await _prefs.expandedCourseIds();
    } catch (_) {
      return null;
    }
  }

  /// Persists [ids] as the full set of expanded sections. Optimistic with
  /// rollback on a write failure (mirrors `StudyAppearanceController`).
  Future<void> setExpanded(Set<String> ids) async {
    final rollback = state;
    state = AsyncData(ids);
    final result = await AsyncValue.guard(() async {
      await _prefs.setExpandedCourseIds(ids);
      return ids;
    });
    state = result.hasError ? rollback : result;
  }
}
