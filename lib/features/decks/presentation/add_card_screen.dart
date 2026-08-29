import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_geometry.dart';
import '../../../theme/app_tokens.dart';
import '../application/deck_providers.dart';
import '../domain/keyword_validator.dart';

/// Add Card (`/deck/:deckId/add-card`) — a rapid single-card entry screen.
///
/// Reached straight after creating a deck and from the study-session dead-ends
/// (ui-spec-v1 had no card-authoring UI). One unified card — Front, Back, and an
/// optional Keyword for Cloze — matching the read-time model (`cards` has no
/// `type` column).
///
/// "Save" writes through [DecksController.addCard] and, instead of popping,
/// clears the fields and drops focus back on Front so the next card can be typed
/// straight in. Card authoring is online-only by the repository's design; a
/// failed write surfaces as a SnackBar and the fields keep their content.
class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key, required this.deckId, this.deckName});

  final String deckId;
  final String? deckName;

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _keyword = TextEditingController();
  final _frontFocus = FocusNode();

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
    _keyword.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  void _onEdit() => setState(() {});

  bool get _canSave =>
      _front.text.trim().isNotEmpty && _back.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final keyword = _keyword.text.trim();
    final card = await ref.read(decksControllerProvider.notifier).addCard(
          deckId: widget.deckId,
          front: _front.text.trim(),
          back: _back.text.trim(),
          keyword: keyword.isEmpty ? null : keyword,
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
    _keyword.clear();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Card added'),
        duration: Duration(seconds: 1),
      ));
    _frontFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final busy = ref.watch(decksControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              title: widget.deckName == null
                  ? 'Add card'
                  : 'Add card · ${widget.deckName}',
              saveEnabled: _canSave && !busy,
              isSaving: busy,
              onCancel: () => context.pop(),
              onSave: _save,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _field(
                      tokens: tokens,
                      controller: _front,
                      focusNode: _frontFocus,
                      label: 'Front',
                      hint: 'The prompt',
                      autofocus: true,
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
                    _field(
                      tokens: tokens,
                      controller: _keyword,
                      label: 'Keyword (optional)',
                      hint: 'A word from the front or back, for Cloze mode',
                      enabled: !busy,
                      minLines: 1,
                      maxLines: 1,
                      textCapitalization: TextCapitalization.none,
                      validator: (v) => keywordError(
                        v ?? '',
                        front: _front.text,
                        back: _back.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    bool autofocus = false,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
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

/// Cancel / Save header — no `AppBar`, matching the Deck Creator's `_Header`.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.saveEnabled,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final bool saveEnabled;
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          TextButton(
            onPressed: isSaving ? null : onCancel,
            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: saveEnabled ? onSave : null,
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: saveEnabled
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
