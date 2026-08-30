import 'package:flutter/material.dart';

import '../../domain/keyword_validator.dart';

/// Multi-keyword entry for the card forms (docs/spec-v3-card-model.md): type a
/// word and press Enter (or comma) to commit it as a removable chip. Each
/// keyword must appear verbatim in the current front or back text — a candidate
/// that doesn't, or a duplicate, is rejected with a brief inline message and
/// not added.
///
/// A [FormField] so `Form.validate()` still gates Save: [keywordsError] runs
/// over the committed list against the [front] / [back] closures (which read
/// the live controller text, like the old single keyword field did).
class KeywordChipsField extends FormField<List<String>> {
  KeywordChipsField({
    super.key,
    required List<String> initialValue,
    required this.onChanged,
    required super.enabled,
    required this.front,
    required this.back,
  }) : super(
          initialValue: initialValue,
          validator: (value) => keywordsError(
            value ?? const [],
            front: front(),
            back: back(),
          ),
          builder: (state) => _KeywordChipsBody(state as _KeywordChipsFieldState),
        );

  final ValueChanged<List<String>> onChanged;
  final String Function() front;
  final String Function() back;

  @override
  FormFieldState<List<String>> createState() => _KeywordChipsFieldState();
}

class _KeywordChipsFieldState extends FormFieldState<List<String>> {
  final _controller = TextEditingController();
  String? _inlineError;

  KeywordChipsField get _field => widget as KeywordChipsField;

  List<String> get _keywords => value ?? const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final candidate = _controller.text.trim();
    if (candidate.isEmpty) return;
    if (_keywords.contains(candidate)) {
      setState(() => _inlineError = 'Already added.');
      return;
    }
    final problem = keywordError(
      candidate,
      front: _field.front(),
      back: _field.back(),
    );
    if (problem != null) {
      setState(() => _inlineError = problem);
      return;
    }
    final next = [..._keywords, candidate];
    _controller.clear();
    _inlineError = null;
    didChange(next);
    _field.onChanged(next);
  }

  void _remove(String keyword) {
    final next = [..._keywords]..remove(keyword);
    didChange(next);
    _field.onChanged(next);
  }

  void _clearInlineError() {
    if (_inlineError != null) setState(() => _inlineError = null);
  }
}

class _KeywordChipsBody extends StatelessWidget {
  const _KeywordChipsBody(this.state);

  final _KeywordChipsFieldState state;

  @override
  Widget build(BuildContext context) {
    final field = state._field;
    final errorText = state.errorText ?? state._inlineError;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Keywords (optional)',
        helperText: 'Each must appear in the front or back, for Cloze mode.',
        errorText: errorText,
        border: const OutlineInputBorder(),
        enabled: field.enabled,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state._keywords.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final keyword in state._keywords)
                  InputChip(
                    label: Text(keyword),
                    isEnabled: field.enabled,
                    onDeleted: field.enabled ? () => state._remove(keyword) : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: state._controller,
            enabled: field.enabled,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Add a keyword',
            ),
            onChanged: (text) {
              if (text.contains(',')) {
                state._controller.text = text.replaceAll(',', '').trim();
                state._commit();
                return;
              }
              state._clearInlineError();
            },
            onSubmitted: (_) => state._commit(),
          ),
        ],
      ),
    );
  }
}
