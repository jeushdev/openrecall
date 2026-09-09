import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_routes.dart';
import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/common/bounded_bottom_sheet.dart';
import '../../application/deck_providers.dart';

/// The Create menu (ui-spec-v2 §6.1) — the bottom sheet the shell's centre
/// **+** button opens, replacing its old direct push to `/deck-creator`.
///
/// Three rows: **Create course** (→ `/course-creator`), **Create deck** (→
/// `/deck-creator`), and **Import card** (expands an inline picker of the user's
/// decks; picking one opens `/deck/:deckId/import`). With no decks yet, Import
/// card routes to the Deck Creator instead with a one-line hint.
///
/// The codebase's first `showModalBottomSheet`; the static [show] helper mirrors
/// `ParkPromptDialog.show`.
class CreateMenuSheet extends ConsumerStatefulWidget {
  const CreateMenuSheet({super.key});

  static Future<void> show(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return showModalBottomSheet<void>(
      context: context,
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
      builder: (_) => const CreateMenuSheet(),
    );
  }

  @override
  ConsumerState<CreateMenuSheet> createState() => _CreateMenuSheetState();
}

class _CreateMenuSheetState extends ConsumerState<CreateMenuSheet> {
  bool _importExpanded = false;

  /// Pops the sheet, then pushes [path]. The router is read before the pop
  /// because this element's context is defunct once the sheet is gone.
  void _go(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  void _onImportTap() {
    final decks = ref.read(decksProvider).asData?.value;
    if (decks != null && decks.isEmpty) {
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      router.push(AppRoutes.deckCreatorPath);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Create a deck first.')));
      return;
    }
    setState(() => _importExpanded = !_importExpanded);
  }

  /// Closes the sheet and opens the Import screen for [deckId] (ui-spec-v2
  /// §6.4). The router is read before the pop because this element's context is
  /// defunct once the sheet is gone.
  void _openImport(String deckId) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/deck/$deckId/import');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final decks = ref.watch(decksProvider);

    return BoundedBottomSheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _MenuRow(
            rowKey: const ValueKey('create-menu-course'),
            icon: Icons.folder_outlined,
            label: 'Create course',
            tokens: tokens,
            onTap: () => _go(AppRoutes.courseCreatorPath),
          ),
          _MenuRow(
            rowKey: const ValueKey('create-menu-deck'),
            icon: Icons.style_outlined,
            label: 'Create deck',
            tokens: tokens,
            onTap: () => _go(AppRoutes.deckCreatorPath),
          ),
          _MenuRow(
            rowKey: const ValueKey('create-menu-import'),
            icon: Icons.file_download_outlined,
            label: 'Import card',
            tokens: tokens,
            trailing: Icon(
              _importExpanded ? Icons.expand_less : Icons.expand_more,
              color: tokens.textTertiary,
            ),
            onTap: _onImportTap,
          ),
          if (_importExpanded)
            decks.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  "Couldn't load your decks.",
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ),
              data: (list) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final deck in list)
                    _MenuRow(
                      rowKey: ValueKey('create-menu-import-${deck.id}'),
                      icon: Icons.subdirectory_arrow_right,
                      label: deck.name,
                      indented: true,
                      tokens: tokens,
                      onTap: () => _openImport(deck.id),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// One tappable row in the Create menu — leading icon, label, optional trailing
/// widget. `InkWell` + `Row` rather than a raw `ListTile`, matching the app's
/// own list idiom.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.tokens,
    required this.onTap,
    this.trailing,
    this.indented = false,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final AppTokens tokens;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 36 : 20, 16, 20, 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tokens.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
