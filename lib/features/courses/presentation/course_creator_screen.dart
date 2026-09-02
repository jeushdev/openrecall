import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_tokens.dart';
import '../application/course_providers.dart';

/// The eight named accent keys (`courses.accent_color`), in the spec's canonical
/// order (ui-spec-v2 §2). Resolved to colours via `AppTokens.accent(key)`.
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

/// Course Creator (`/course-creator`, ui-spec-v2 §6.2) — name a course, pick its
/// accent colour, create it.
///
/// A top-level route outside the shell (`app_router.dart`), so the bottom nav
/// bar is naturally absent. Header and layout mirror the Deck Creator
/// (`lib/routing/placeholders/deck_creator_screen.dart`). "No blind colour
/// input" (§2): the picker offers exactly the eight named swatches, never a hex
/// field. On success it pops back to the Decks tab — `CourseController.create`
/// already refreshes the course list, deck list, and Decks-tab view.
class CourseCreatorScreen extends ConsumerStatefulWidget {
  const CourseCreatorScreen({super.key});

  @override
  ConsumerState<CourseCreatorScreen> createState() =>
      _CourseCreatorScreenState();
}

class _CourseCreatorScreenState extends ConsumerState<CourseCreatorScreen> {
  final _nameController = TextEditingController();
  String _accentKey = 'slate';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _nameController.text.trim().isNotEmpty;

  Future<void> _create() async {
    final course = await ref.read(courseControllerProvider.notifier).create(
          name: _nameController.text.trim(),
          accentColor: _accentKey,
        );
    if (!mounted) return;

    if (course == null) {
      // Offline authoring falls back to the local queue, so a null result means
      // the local write itself failed. Keep the form so nothing is lost on retry.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text("Couldn't create the course, try again."),
        ));
      return;
    }

    // `CourseController.create` already invalidates coursesProvider /
    // decksProvider / decksTabViewProvider — just step back to the Decks tab.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final isSubmitting = ref.watch(courseControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              createEnabled: _canSubmit && !isSubmitting,
              isSubmitting: isSubmitting,
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
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_canSubmit && !isSubmitting) _create();
                    },
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'Course name'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AccentSwatches(
                    tokens: tokens,
                    selected: _accentKey,
                    onSelected: (key) => setState(() => _accentKey = key),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cancel / Create header — no `AppBar`, copied from the Deck Creator's
/// `_Header` (ui-spec-v2 §6.2).
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

/// A single-select row of the eight named accent swatches. Each is a filled
/// circle in `accent(key).fill`; the selected one carries a ring in
/// `accent(key).text` (ui-spec-v2 §6.2).
class _AccentSwatches extends StatelessWidget {
  const _AccentSwatches({
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
