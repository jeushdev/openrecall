import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../application/deck_providers.dart';
import '../domain/deck.dart';
import 'widgets/bulk_paste_panel.dart';
import 'widgets/keyword_chips_field.dart';

/// Import cards (`/deck/:deckId/import`, ui-spec-v2 §6.4) — the single screen
/// that folds together rapid single-card entry and bulk AI-paste import.
///
/// A top-level route outside the shell (`app_router.dart`), so the bottom nav
/// bar is absent. The manual section reuses the old `AddCardScreen`'s field set
/// and `_save` behaviour (write → clear + refocus Front + a 1s "Card added"
/// snackbar, never pop). The bulk section embeds [BulkPastePanel], which already
/// does the Copy-AI-prompt button, the debounced live preview that flags bad
/// lines with a reason, and the "Add N cards" write. A footer links to the card
/// list (U15) and to a study session for the deck.
class ImportCardsScreen extends ConsumerStatefulWidget {
  const ImportCardsScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<ImportCardsScreen> createState() => _ImportCardsScreenState();
}

class _ImportCardsScreenState extends ConsumerState<ImportCardsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _frontFocus = FocusNode();
  List<String> _keywords = [];
  bool _isConcept = false;

  /// Bumped after each successful add so the keyword-chips [FormField] is
  /// rebuilt fresh (it only reads `initialValue` on first build).
  int _formGen = 0;

  @override
  void initState() {
    super.initState();
    _front.addListener(_onEdit);
    _back.addListener(_onEdit);
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  void _onEdit() => setState(() {});

  bool get _canSave =>
      _front.text.trim().isNotEmpty && _back.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final card = await ref.read(decksControllerProvider.notifier).addCard(
          deckId: widget.deckId,
          front: _front.text.trim(),
          back: _back.text.trim(),
          keywords: _keywords,
          isConcept: _isConcept,
        );

    if (!mounted) return;

    if (card == null) {
      // The write failed (card authoring is online-only by the repository's
      // design). Keep the fields as they are so nothing is lost on retry.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text(
            "Couldn't save the card. Check your connection and try again.",
          ),
        ));
      return;
    }

    _formKey.currentState!.reset();
    _front.clear();
    _back.clear();
    setState(() {
      _keywords = [];
      _isConcept = false;
      _formGen++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Card added'),
        duration: Duration(seconds: 1),
      ));
    _frontFocus.requestFocus();
  }

  String? _deckName(AsyncValue<List<DeckSummary>> decks) {
    for (final deck in decks.asData?.value ?? const <DeckSummary>[]) {
      if (deck.id == widget.deckId) return deck.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final busy = ref.watch(decksControllerProvider).isLoading;
    final deckName = _deckName(ref.watch(decksProvider));

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: Text(deckName ?? 'Deck'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Done', style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionHeading('Add a card', tokens: tokens),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  tokens: tokens,
                  controller: _front,
                  focusNode: _frontFocus,
                  label: 'Front',
                  hint: 'The prompt',
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 6,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Enter the front of the card.'
                      : null,
                ),
                const SizedBox(height: 16),
                _field(
                  tokens: tokens,
                  controller: _back,
                  label: 'Back',
                  hint: 'The answer — one point per line for List / Feynman',
                  enabled: !busy,
                  minLines: 4,
                  maxLines: 10,
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Enter the back of the card.'
                      : null,
                ),
                const SizedBox(height: 16),
                KeywordChipsField(
                  key: ValueKey(_formGen),
                  initialValue: _keywords,
                  onChanged: (v) => setState(() => _keywords = v),
                  enabled: !busy,
                  front: () => _front.text,
                  back: () => _back.text,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isConcept,
                  onChanged:
                      busy ? null : (v) => setState(() => _isConcept = v),
                  title: Text(
                    'Concept card',
                    style: TextStyle(color: tokens.textPrimary),
                  ),
                  subtitle: Text(
                    'Enables Feynman mode — explain it in your own words.',
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_canSave && !busy) ? _save : null,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add card'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Divider(color: tokens.borderHairline, height: 1),
          const SizedBox(height: 16),
          _SectionHeading('Bulk import', tokens: tokens),
          const SizedBox(height: 4),
          BulkPastePanel(deckId: widget.deckId, initiallyExpanded: true),
          const SizedBox(height: 24),
          Divider(color: tokens.borderHairline, height: 1),
          _FooterRow(
            label: 'View cards',
            icon: Icons.list_alt_outlined,
            tokens: tokens,
            onTap: () => context.pushNamed(
              AppRoutes.cardListName,
              pathParameters: {'deckId': widget.deckId},
            ),
          ),
          _FooterRow(
            label: 'Start session',
            icon: Icons.play_arrow_outlined,
            tokens: tokens,
            onTap: () => context.pushNamed(
              AppRoutes.studySessionName,
              pathParameters: {'deckId': widget.deckId},
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required AppTokens tokens,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool enabled,
    required int minLines,
    required int maxLines,
    FocusNode? focusNode,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: TextStyle(color: tokens.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: tokens.textSecondary),
        floatingLabelStyle: TextStyle(color: tokens.textSecondary),
        hintStyle: TextStyle(color: tokens.textTertiary),
        filled: true,
        fillColor: tokens.mutedFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.gridTileRadius,
          borderSide: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.gridTileRadius,
          borderSide: BorderSide(
            color: tokens.textSecondary,
            width: AppBorders.hairline,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.gridTileRadius,
          borderSide: BorderSide(
            color: tokens.borderHairline,
            width: AppBorders.hairline,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.gridTileRadius,
          borderSide: BorderSide(
            color: tokens.accent('red').text,
            width: AppBorders.hairline,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.gridTileRadius,
          borderSide: BorderSide(
            color: tokens.accent('red').text,
            width: AppBorders.hairline,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text, {required this.tokens});

  final String text;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: tokens.textPrimary,
      ),
    );
  }
}

/// A footer navigation row — leading icon, label, trailing chevron. Mirrors
/// `DeckDetailScreen._ViewCardsRow`'s idiom.
class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.label,
    required this.icon,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AppTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tokens.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
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
