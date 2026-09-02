import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/courses/application/course_providers.dart';
import '../../features/decks/application/deck_creator_controller.dart';
import '../../features/decks/application/decks_tab_view.dart';
import '../../features/decks/presentation/widgets/course_selector.dart';
import '../../theme/app_tokens.dart';
import '../app_routes.dart';

/// The Deck Creator (`/deck-creator`, ui-spec-v1 §4) — name a deck, optionally
/// pick the course it belongs to, create it.
///
/// A top-level route outside the shell (`app_router.dart`), so the bottom nav
/// bar is naturally absent while creating a deck. Course selection is read-only
/// here: it lists the existing courses from [coursesProvider] and sets the new
/// deck's `course_id` — creating or editing a course is out of scope (blocked,
/// ui-spec-v1 §7). Accent colour lives on the course, never on the deck, so
/// there is no colour picker on this screen. Picking a course is optional: when
/// the list is unavailable (offline, empty mirror) the deck is created with no
/// course and lands in the user's default course.
///
/// (This file keeps the `placeholders/` path and `DeckCreatorScreen` name the
/// router and its tests already use; it shares the name with the unrelated,
/// not-yet-rewired card-manager in `lib/features/decks/presentation/` — a
/// different library, never imported together.)
class DeckCreatorScreen extends ConsumerStatefulWidget {
  const DeckCreatorScreen({super.key});

  @override
  ConsumerState<DeckCreatorScreen> createState() => _DeckCreatorScreenState();
}

class _DeckCreatorScreenState extends ConsumerState<DeckCreatorScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final deckId =
        await ref.read(deckCreatorControllerProvider.notifier).submit();
    if (deckId == null || !mounted) return;
    // The Decks tab's grid reads its own provider (not `decksProvider`), and the
    // shell stays mounted underneath this route — refresh it so the new deck is
    // there when we come back.
    refreshDecksTab(ref);
    // Into the new deck's detail screen (ui-spec-v2 §6.3), where the user can
    // import cards or start a session. `pushReplacement` so Back from there
    // returns to the Decks tab, not this now-stale form.
    context.pushReplacementNamed(
      AppRoutes.deckDetailName,
      pathParameters: {'deckId': deckId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final form = ref.watch(deckCreatorControllerProvider);
    final controller = ref.read(deckCreatorControllerProvider.notifier);
    final courses = ref.watch(coursesProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              createEnabled: form.canSubmit,
              isSubmitting: form.isSubmitting,
              onCancel: () => context.pop(),
              onCreate: _create,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: controller.nameChanged,
                    onSubmitted: (_) {
                      if (form.canSubmit) _create();
                    },
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'Deck name'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Course',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  courses.when(
                    loading: () => const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => _CoursesUnavailable(
                      onRetry: () => ref.invalidate(coursesProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? const _CoursesUnavailable()
                        : CourseSelector(
                            courses: list,
                            selectedId: form.selectedCourseId,
                            onSelected: controller.courseSelected,
                          ),
                  ),
                  if (form.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      form.error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.accent('red').text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.createEnabled,
    required this.isSubmitting,
    required this.onCancel,
    required this.onCreate,
  });

  final bool createEnabled;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: isSubmitting ? null : onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: createEnabled ? onCreate : null,
            child: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: createEnabled
                          ? tokens.textPrimary
                          : tokens.textTertiary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the course list can't be loaded (offline with an empty mirror) or
/// is genuinely empty. Creating the deck is still allowed — it lands in the
/// default course — so this is an informational note, not a blocking error.
class _CoursesUnavailable extends StatelessWidget {
  const _CoursesUnavailable({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Courses are unavailable right now — this deck goes to your '
            'default course. You can move it later.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: tokens.textSecondary,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
