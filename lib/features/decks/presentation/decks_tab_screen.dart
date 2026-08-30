import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../courses/application/course_providers.dart';
import '../../courses/domain/course.dart';
import '../application/decks_tab_view.dart';
import 'widgets/deck_grid.dart';

/// The Decks tab (`/decks`, ui-spec-v2 §5) — the app's home screen.
///
/// A "Decks" header over an accordion of collapsible course sections. Each
/// section has a header (a 4px accent bar + course name + "N decks" + a chevron
/// + a ⋮ overflow with Edit / Delete course) and, when expanded, a 2-column grid
/// of that course's deck tiles. There is no Due / All segmented control — the Due
/// view is retired (§1) and every session runs `CardScope.all`.
///
/// The grid reads real decks from [decksTabViewProvider] (cache-first, so it
/// degrades to the local mirror / an empty list offline). Expand/collapse state
/// is persisted per course id via [expandedCoursesProvider].
class DecksTabScreen extends ConsumerWidget {
  const DecksTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(courseControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

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

  Future<void> _editCourse(BuildContext context, Course course) =>
      _CourseEditSheet.show(context, course: course);

  Future<void> _deleteCourse(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete course?'),
        content: const Text('Its decks move to Uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(courseControllerProvider.notifier).delete(course.id);
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
            // The synthetic fallback course (userId == '') is only shown while
            // the course list is still loading / failed — it has no real id to
            // write against, so it carries no menu.
            onEditCourse: group.course.userId.isEmpty
                ? null
                : () => _editCourse(context, group.course),
            // The default course is never deletable (ui-spec-v2 §3.1 / §7).
            onDeleteCourse:
                group.course.userId.isEmpty || group.course.isDefault
                    ? null
                    : () => _deleteCourse(context, ref, group.course),
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
    required this.onEditCourse,
    required this.onDeleteCourse,
  });

  final CourseDeckGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onEditCourse;
  final VoidCallback? onDeleteCourse;

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
          onEditCourse: onEditCourse,
          onDeleteCourse: onDeleteCourse,
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
          else ...[
            if (group.decks.isEmpty && group.course.isDefault)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'No decks yet — create one to get started.',
                  style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                ),
              ),
            DeckGrid(
              decks: group.decks,
              showCreateTile: group.course.isDefault,
            ),
          ],
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

enum _CourseAction { edit, delete }

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({
    required this.name,
    required this.deckCount,
    required this.accent,
    required this.expanded,
    required this.onTap,
    required this.onEditCourse,
    required this.onDeleteCourse,
  });

  final String name;
  final int deckCount;
  final AccentPair accent;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onEditCourse;
  final VoidCallback? onDeleteCourse;

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
              if (onEditCourse != null)
                PopupMenuButton<_CourseAction>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Course options',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.more_vert, color: tokens.textSecondary),
                  ),
                  onSelected: (action) => switch (action) {
                    _CourseAction.edit => onEditCourse!(),
                    _CourseAction.delete => onDeleteCourse!(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _CourseAction.edit,
                      child: Text('Edit course'),
                    ),
                    if (onDeleteCourse != null)
                      const PopupMenuItem(
                        value: _CourseAction.delete,
                        child: Text('Delete course'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The eight named accent keys (`courses.accent_color`), in the spec's canonical
/// order (ui-spec-v2 §2). Mirrors the Course Creator's list — kept local because
/// that screen's swatch widget is private.
const List<String> _accentKeys = [
  'slate',
  'red',
  'amber',
  'green',
  'teal',
  'blue',
  'violet',
  'pink',
];

/// Rename and/or recolor a course (ui-spec-v2 §7), submitting to
/// [CourseController.updateCourse]. The bottom-sheet idiom mirrors
/// `DeckDetailScreen._DeckEditSheet`.
class _CourseEditSheet extends ConsumerStatefulWidget {
  const _CourseEditSheet({required this.course});

  final Course course;

  static Future<void> show(BuildContext context, {required Course course}) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.cardFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      builder: (_) => _CourseEditSheet(course: course),
    );
  }

  @override
  ConsumerState<_CourseEditSheet> createState() => _CourseEditSheetState();
}

class _CourseEditSheetState extends ConsumerState<_CourseEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.course.name);
  late String _accentKey = widget.course.accentColor;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final course = await ref.read(courseControllerProvider.notifier).updateCourse(
          id: widget.course.id,
          name: name,
          accentColor: _accentKey,
        );
    if (!mounted) return;
    if (course != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final busy = ref.watch(courseControllerProvider).isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit course',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_canSave && !busy) _save();
              },
              style: TextStyle(color: tokens.textPrimary),
              decoration: InputDecoration(
                labelText: 'Course name',
                labelStyle: TextStyle(color: tokens.textSecondary),
                floatingLabelStyle: TextStyle(color: tokens.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputRadius,
                  borderSide: BorderSide(
                    color: tokens.borderHairline,
                    width: AppBorders.hairline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.inputRadius,
                  borderSide: BorderSide(
                    color: tokens.textSecondary,
                    width: AppBorders.hairline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _AccentPicker(
              tokens: tokens,
              selected: _accentKey,
              onSelected: (key) => setState(() => _accentKey = key),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_canSave && !busy) ? _save : null,
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single-select row of the eight named accent swatches — a filled circle in
/// `accent(key).fill`, the selected one ringed in `accent(key).text`. Mirrors
/// the Course Creator's private `_AccentSwatches`.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({
    required this.tokens,
    required this.selected,
    required this.onSelected,
  });

  final AppTokens tokens;
  final String selected;
  final ValueChanged<String> onSelected;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final key in _accentKeys)
          GestureDetector(
            key: ValueKey('accent-$key'),
            onTap: () => onSelected(key),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: tokens.accent(key).fill,
                shape: BoxShape.circle,
                border: key == selected
                    ? Border.all(color: tokens.accent(key).text, width: 3)
                    : null,
              ),
              child: key == selected
                  ? Icon(Icons.check,
                      size: 20, color: tokens.accent(key).text)
                  : null,
            ),
          ),
      ],
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
