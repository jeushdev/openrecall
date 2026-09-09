import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/ui/app_messenger.dart';
import '../../courses/application/course_providers.dart';
import '../../courses/domain/course.dart';
import '../domain/deck.dart';
import 'deck_providers.dart';
import 'offline_providers.dart';
import 'pending_deletions.dart';

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
    this.isLockedOffline = false,
    this.isAvailableOffline = false,
  });

  /// The real `decks.id` — handed straight to `/study/:deckId`.
  final String id;
  final String name;

  /// Total cards in the deck — the tile badge shows `"{n} cards"` (§5).
  final int cardCount;

  /// One of the eight `courses.accent_color` keys, resolved through the deck's
  /// parent course. Falls back to `slate` when the course is unknown.
  final String accentKey;

  /// True when the app is offline and this deck has no verified complete local
  /// card set, so it cannot be opened or studied.
  final bool isLockedOffline;

  /// True only for a persisted explicit package, including after restart.
  final bool isAvailableOffline;
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

/// Compatibility name for callers that conceptually read the tab's decks. The
/// data now comes from the same local-first observable used app-wide.
final tabDecksProvider = decksProvider;

/// The Decks-tab accordion model (ui-spec-v2 §5): the user's courses ordered by
/// `created_at` ascending — so the default course sorts first — each with its
/// decks.
///
/// Driven by the shared local-first [decksProvider].
/// [coursesProvider] is best-effort enrichment: while it loads or if it fails,
/// every deck falls into a single synthetic group so the tab still renders
/// rather than blocking.
final decksTabViewProvider = Provider<AsyncValue<List<CourseDeckGroup>>>((ref) {
  final decksAsync = ref.watch(decksProvider);
  final courses = ref.watch(coursesProvider).asData?.value ?? const <Course>[];

  // Optimistically-deleted courses / decks (milestone R1) are subtracted before
  // grouping. Dropping a pending course from the list is enough to re-home its
  // decks: `_group` routes any deck whose course id it doesn't recognise to the
  // default course.
  final pending = ref.watch(pendingDeletionsProvider);

  // Optimistic drag-reorder overrides (milestone B): applied on top of the
  // server `position` order until the persisted refetch catches up.
  final order = ref.watch(tabOrderProvider);

  // A deck the app can't open offline (design spec §E.1). Assume online until
  // connectivity resolves, so tiles never flash locked on a cold start.
  final online = ref.watch(onlineStatusProvider).asData?.value ?? true;
  final studiable =
      ref.watch(studiableOfflineDeckIdsProvider).asData?.value ??
      const <String>{};
  final pinned =
      ref.watch(offlineDeckIdsProvider).asData?.value ?? const <String>{};

  return decksAsync.whenData((decks) {
    final visibleDecks = pending.deckIds.isEmpty
        ? decks
        : decks.where((d) => !pending.deckIds.contains(d.id)).toList();
    final visibleCourses = pending.courseIds.isEmpty
        ? courses
        : courses.where((c) => !pending.courseIds.contains(c.id)).toList();
    return _group(
      visibleDecks,
      visibleCourses,
      order,
      online: online,
      studiable: studiable,
      pinned: pinned,
    );
  });
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

List<CourseDeckGroup> _group(
  List<DeckSummary> decks,
  List<Course> courses,
  TabOrder order, {
  required bool online,
  required Set<String> studiable,
  required Set<String> pinned,
}) {
  DeckTileView tile(DeckSummary d, String accentKey) => DeckTileView(
    id: d.id,
    name: d.name,
    cardCount: d.totalCards,
    accentKey: accentKey,
    // On web there is no local mirror and nothing is ever "studiable
    // offline", so an offline browser would otherwise lock every tile with
    // copy about downloading (spec-web-mvp §5.3). The web build is
    // online-only by design; leave tiles unlocked.
    isLockedOffline: !kIsWeb && !online && !studiable.contains(d.id),
    isAvailableOffline: pinned.contains(d.id),
  );

  if (courses.isEmpty) {
    return [
      CourseDeckGroup(
        course: _syntheticDefaultCourse,
        decks: [
          for (final d in decks) tile(d, _syntheticDefaultCourse.accentColor),
        ],
      ),
    ];
  }

  // Server order: `position` ascending, ties broken by `created_at` (stable via
  // the original index). The optimistic course-drag override, when present,
  // wins over that.
  final ordered = _sortByPosition(
    courses,
    (c) => c.position,
    (c) => c.createdAt,
  );
  final courseGroups = _applyOverride(ordered, order.courseOrder, (c) => c.id);

  final byId = {for (final c in courseGroups) c.id: c};
  final defaultCourse = courseGroups.firstWhere(
    (c) => c.isDefault,
    orElse: () => courseGroups.first,
  );

  final buckets = {for (final c in courseGroups) c.id: <DeckSummary>[]};
  for (final d in decks) {
    final course = byId[d.courseId] ?? defaultCourse;
    buckets[course.id]!.add(d);
  }

  return [
    for (final c in courseGroups)
      CourseDeckGroup(
        course: c,
        decks: [
          for (final d in _applyOverride(
            _sortByPosition(buckets[c.id]!, (d) => d.position, (_) => null),
            order.deckOrders[c.id],
            (d) => d.id,
          ))
            tile(d, c.accentColor),
        ],
      ),
  ];
}

/// A stable sort by [position] ascending, ties broken by [tiebreak] (a
/// `DateTime` or null) and then by the original index, so equal-position rows
/// keep the order the server sent them in.
List<T> _sortByPosition<T>(
  List<T> items,
  int Function(T) position,
  DateTime? Function(T) tiebreak,
) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byPos = position(a.$2).compareTo(position(b.$2));
      if (byPos != 0) return byPos;
      final ta = tiebreak(a.$2);
      final tb = tiebreak(b.$2);
      if (ta != null && tb != null) {
        final byTime = ta.compareTo(tb);
        if (byTime != 0) return byTime;
      }
      return a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// Reorders [items] to match the id sequence [order] (an optimistic drag
/// override). Items named in [order] come first, in that sequence; anything not
/// named keeps its position at the end. A null [order] is a no-op.
List<T> _applyOverride<T>(
  List<T> items,
  List<String>? order,
  String Function(T) idOf,
) {
  if (order == null) return items;
  final byId = {for (final it in items) idOf(it): it};
  final result = <T>[for (final id in order) ?byId.remove(id)];
  result.addAll(byId.values);
  return result;
}

/// Re-runs the deck-list and course fetches (Retry on the error state).
void refreshDecksTab(WidgetRef ref) {
  ref.invalidate(decksProvider);
  ref.invalidate(coursesProvider);
}

/// The optimistic drag-reorder overrides for the Decks tab (milestone B).
///
/// [courseOrder] is the user's just-dragged course-id sequence (null when the
/// server `position` order is authoritative); [deckOrders] maps a course id to
/// its just-dragged deck-id sequence. Each override is held only until the
/// persisted new positions come back from Supabase, then cleared so server and
/// UI agree.
@immutable
class TabOrder {
  const TabOrder({this.courseOrder, this.deckOrders = const {}});

  final List<String>? courseOrder;
  final Map<String, List<String>> deckOrders;
}

final tabOrderProvider = NotifierProvider<TabOrderController, TabOrder>(
  TabOrderController.new,
);

/// Handles a drag-to-reorder gesture on the Decks tab: apply the new order to
/// [tabOrderProvider] at once (optimistic), persist it in one batched call, and
/// on failure revert the override and surface a snackbar (ui-spec-v2 / milestone
/// B). Offline the persist simply throws and the revert fires — the milestone E
/// write queue will later absorb these.
class TabOrderController extends Notifier<TabOrder> {
  @override
  TabOrder build() => const TabOrder();

  static const _failureMessage =
      "Couldn't save the new order — check your connection.";

  Future<void> reorderCourses(List<String> newOrder) async {
    final previous = state;
    state = TabOrder(courseOrder: newOrder, deckOrders: previous.deckOrders);
    try {
      await ref.read(courseRepositoryProvider).reorderCourses(newOrder);
    } catch (_) {
      state = previous;
      showAppSnackBar(_failureMessage);
      return;
    }
    await _settleAfter(() {
      ref.invalidate(coursesProvider);
      ref.invalidate(decksProvider);
      return ref.read(coursesProvider.future);
    });
    state = TabOrder(courseOrder: null, deckOrders: state.deckOrders);
  }

  Future<void> reorderDecks(String courseId, List<String> newOrder) async {
    final previous = state;
    state = TabOrder(
      courseOrder: previous.courseOrder,
      deckOrders: {...previous.deckOrders, courseId: newOrder},
    );
    try {
      await ref.read(deckRepositoryProvider).reorderDecks(newOrder);
    } catch (_) {
      state = previous;
      showAppSnackBar(_failureMessage);
      return;
    }
    await _settleAfter(() {
      ref.invalidate(decksProvider);
      return ref.read(tabDecksProvider.future);
    });
    state = TabOrder(
      courseOrder: state.courseOrder,
      deckOrders: {...state.deckOrders}..remove(courseId),
    );
  }

  /// Invalidates and awaits the refetch so the cleared override hands off to a
  /// list that already carries the new `position` values — no reorder flicker.
  /// A refetch failure is swallowed: the write already succeeded.
  Future<void> _settleAfter(Future<Object?> Function() refetch) async {
    try {
      await refetch();
    } catch (_) {
      // The persist landed; a failed refresh doesn't undo it.
    }
  }
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

final decksAccordionPreferencesProvider = Provider<DecksAccordionPreferences>(
  (ref) => DecksAccordionPreferences(),
);

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
