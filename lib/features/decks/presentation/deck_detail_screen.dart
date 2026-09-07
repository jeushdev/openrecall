import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/common/bounded_bottom_sheet.dart';
import '../../courses/application/course_providers.dart';
import '../../study/domain/study_session.dart';
import '../../study/presentation/study_session_args.dart';
import '../../study/presentation/widgets/mode_picker.dart';
import '../application/deck_providers.dart';
import '../domain/deck.dart';
import '../domain/study_mode.dart';
import 'widgets/course_selector.dart';

/// Deck detail (`/deck/:deckId`, ui-spec-v2 §6.3) — the screen a deck tile opens
/// instead of dropping straight into a study session.
///
/// A top-level route outside the shell (`app_router.dart`), so the bottom nav
/// bar is absent. The body reuses [availableModes] over [deckCardsProvider] and
/// the [ModePicker] widget; picking any mode pushes `/study/:deckId`, where the
/// session (always `CardScope.all` since U12) is built — Feynman still detours
/// through the timer picker there. Below the picker, a "View cards (N)" row
/// opens the card list (U15). The app bar carries an Import action (U14) and a
/// ⋮ overflow with Edit / Delete deck.
class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(decksControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Something went wrong: $error')),
          );
      }
    });

    final tokens = Theme.of(context).extension<AppTokens>()!;
    final deckName = _deckName(ref.watch(decksProvider));
    final cards = ref.watch(deckCardsProvider(deckId));

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(deckName ?? 'Deck'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Import',
            onPressed: () => context.pushNamed(
              AppRoutes.importCardsName,
              pathParameters: {'deckId': deckId},
            ),
          ),
          PopupMenuButton<_DeckAction>(
            onSelected: (action) => switch (action) {
              _DeckAction.edit => _editDeck(context),
              _DeckAction.delete => _deleteDeck(context, ref),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _DeckAction.edit,
                child: Text('Edit deck'),
              ),
              PopupMenuItem(
                value: _DeckAction.delete,
                child: Text('Delete deck'),
              ),
            ],
          ),
        ],
      ),
      body: cards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _CardsError(
          onRetry: () => ref.invalidate(deckCardsProvider(deckId)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _AddCardsCta(
              onTap: () => context.pushNamed(
                AppRoutes.importCardsName,
                pathParameters: {'deckId': deckId},
              ),
            );
          }
          final modes =
              StudyMode.values.where(availableModes(list).contains).toList();
          return Column(
            children: [
              Expanded(
                child: ModePicker(
                  modes: modes,
                  onSelected: (mode) => context.pushNamed(
                    AppRoutes.studySessionName,
                    pathParameters: {'deckId': deckId},
                    extra: StudySessionArgs(
                      deckId: deckId,
                      deckName: deckName,
                      mode: mode,
                      cardScope: CardScope.all,
                    ),
                  ),
                ),
              ),
              _ViewCardsRow(
                count: list.length,
                onTap: () => context.pushNamed(
                  AppRoutes.cardListName,
                  pathParameters: {'deckId': deckId},
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  String? _deckName(AsyncValue<List<DeckSummary>> decks) {
    for (final deck in decks.asData?.value ?? const <DeckSummary>[]) {
      if (deck.id == deckId) return deck.name;
    }
    return null;
  }

  Future<void> _editDeck(BuildContext context) =>
      _DeckEditSheet.show(context, deckId: deckId);

  Future<void> _deleteDeck(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete deck?'),
        content: const Text(
          'This removes it and its cards permanently.',
        ),
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

    // Optimistic (milestone R1): the deck drops out of the Decks-tab grid
    // immediately and we pop back now. The repo write runs in the background;
    // on failure `DecksController` restores the row and shows a snackbar
    // through the app-wide messenger, since this screen is already gone.
    ref.read(decksControllerProvider.notifier).deleteDeck(deckId);
    if (context.canPop()) context.pop();
  }
}

enum _DeckAction { edit, delete }

/// Rename a deck and/or move it to another course (ui-spec-v2 §6.3), submitting
/// to [DecksController.updateDeck]. The codebase's bottom-sheet idiom mirrors
/// `CreateMenuSheet.show`.
class _DeckEditSheet extends ConsumerStatefulWidget {
  const _DeckEditSheet({required this.deckId});

  final String deckId;

  static Future<void> show(BuildContext context, {required String deckId}) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: tokens.cardFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(
          color: tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      builder: (_) => _DeckEditSheet(deckId: deckId),
    );
  }

  @override
  ConsumerState<_DeckEditSheet> createState() => _DeckEditSheetState();
}

class _DeckEditSheetState extends ConsumerState<_DeckEditSheet> {
  late final TextEditingController _name;
  String? _courseId;

  @override
  void initState() {
    super.initState();
    final decks = ref.read(decksProvider).asData?.value ?? const <DeckSummary>[];
    DeckSummary? deck;
    for (final d in decks) {
      if (d.id == widget.deckId) deck = d;
    }
    _name = TextEditingController(text: deck?.name ?? '');
    _courseId = deck?.courseId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final deck = await ref.read(decksControllerProvider.notifier).updateDeck(
          id: widget.deckId,
          name: name,
          courseId: _courseId,
        );
    if (!mounted) return;
    if (deck != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final courses = ref.watch(coursesProvider);
    final busy = ref.watch(decksControllerProvider).isLoading;

    return BoundedBottomSheetBody(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              'Edit deck',
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
                labelText: 'Deck name',
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
              error: (_, _) => Text(
                "Couldn't load your courses.",
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
              ),
              data: (list) => CourseSelector(
                courses: list,
                selectedId: _courseId,
                onSelected: (id) => setState(() => _courseId = id),
              ),
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

/// The "View cards (N)" row under the mode picker (ui-spec-v2 §6.3) — opens the
/// card list (U15).
class _ViewCardsRow extends StatelessWidget {
  const _ViewCardsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'View cards ($count)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the deck has no cards yet — a call to action into the import
/// screen (ui-spec-v2 §6.3).
class _AddCardsCta extends StatelessWidget {
  const _AddCardsCta({required this.onTap});

  final VoidCallback onTap;

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
              'This deck has no cards yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onTap, child: const Text('Add cards')),
          ],
        ),
      ),
    );
  }
}

class _CardsError extends StatelessWidget {
  const _CardsError({required this.onRetry});

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
              "Couldn't load this deck's cards.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: tokens.textPrimary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
