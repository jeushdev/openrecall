import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_tokens.dart';
import '../../courses/domain/course.dart';
import '../application/decks_tab_view.dart';
import 'widgets/deck_grid.dart';

/// The Decks tab (`/decks`, ui-spec-v2 §5) — the app's home screen.
///
/// A "Decks" header over an accordion of collapsible course sections. Each
/// section has a header (a 4px accent bar + course name + "N decks" + a chevron)
/// and, when expanded, a 2-column grid of that course's deck tiles. There is no
/// Due / All segmented control — the Due view is retired (§1) and every session
/// runs `CardScope.all`.
///
/// The grid reads real decks from [decksTabViewProvider] (cache-first, so it
/// degrades to the local mirror / an empty list offline). Expand/collapse state
/// is persisted per course id via [expandedCoursesProvider].
class DecksTabScreen extends ConsumerWidget {
  const DecksTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final groups = ref.watch(decksTabViewProvider);
    final stored = ref.watch(expandedCoursesProvider).asData?.value;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Decks',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: groups.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => _DecksError(
                  onRetry: () => refreshDecksTab(ref),
                ),
                data: (list) => _Accordion(groups: list, stored: stored),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list of collapsible course sections. A course is expanded when the user
/// has explicitly expanded it; before they have touched anything ([stored] is
/// `null`), only the default course is open (ui-spec-v2 §5).
class _Accordion extends ConsumerWidget {
  const _Accordion({required this.groups, required this.stored});

  final List<CourseDeckGroup> groups;
  final Set<String>? stored;

  bool _isExpanded(Course course) =>
      stored?.contains(course.id) ?? course.isDefault;

  /// Materialises the currently-resolved expanded set across every section,
  /// flips [course], and persists the result — so behaviour is deterministic
  /// once the user has toggled anything.
  void _toggle(WidgetRef ref, Course course) {
    final next = {
      for (final g in groups)
        if (_isExpanded(g.course)) g.course.id,
    };
    if (!next.remove(course.id)) next.add(course.id);
    ref.read(expandedCoursesProvider.notifier).setExpanded(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        for (final group in groups)
          _CourseSection(
            group: group,
            expanded: _isExpanded(group.course),
            onToggle: () => _toggle(ref, group.course),
          ),
      ],
    );
  }
}

class _CourseSection extends StatelessWidget {
  const _CourseSection({
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  final CourseDeckGroup group;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(group.course.accentColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CourseHeader(
          name: group.course.name,
          deckCount: group.decks.length,
          accent: accent,
          expanded: expanded,
          onTap: onToggle,
        ),
        if (expanded) ...[
          const SizedBox(height: 12),
          if (group.decks.isEmpty && !group.course.isDefault)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                'No decks yet',
                style: TextStyle(fontSize: 13, color: tokens.textTertiary),
              ),
            )
          else
            DeckGrid(
              decks: group.decks,
              showCreateTile: group.course.isDefault,
            ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({
    required this.name,
    required this.deckCount,
    required this.accent,
    required this.expanded,
    required this.onTap,
  });

  final String name;
  final int deckCount;
  final AccentPair accent;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.fill,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$deckCount decks',
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.expand_more, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the deck list can't be loaded (no connection and nothing mirrored
/// locally). The trailing Create tile still lives inside [DeckGrid] for the
/// empty-but-loaded case; this is only the hard-failure state.
class _DecksError extends StatelessWidget {
  const _DecksError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load your decks.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.push(AppRoutes.deckCreatorPath),
              child: const Text('Create a deck'),
            ),
          ],
        ),
      ),
    );
  }
}
