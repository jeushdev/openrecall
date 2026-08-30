import 'package:flutter/material.dart';

import 'keyword_chips_field.dart';

/// The content fields shared by the add-card form and the edit-card dialog
/// (docs/spec-v3-card-model.md): Front, Back (one line or many), the Cloze
/// [keywords] chips, and the [isConcept] toggle.
///
/// Wrap in a [Form] and supply the controllers. Keywords are validated against
/// the current front/back text via [KeywordChipsField].
class CardFields extends StatelessWidget {
  const CardFields({
    super.key,
    required this.frontController,
    required this.backController,
    required this.keywords,
    required this.onKeywordsChanged,
    required this.isConcept,
    required this.onIsConceptChanged,
    required this.enabled,
  });

  final TextEditingController frontController;
  final TextEditingController backController;
  final List<String> keywords;
  final ValueChanged<List<String>> onKeywordsChanged;
  final bool isConcept;
  final ValueChanged<bool> onIsConceptChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: frontController,
          enabled: enabled,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Front',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the front of the card.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: backController,
          enabled: enabled,
          minLines: 1,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Back',
            helperText: 'One line, or one point per line for a concept card.',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the back of the card.' : null,
        ),
        const SizedBox(height: 12),
        KeywordChipsField(
          initialValue: keywords,
          onChanged: onKeywordsChanged,
          enabled: enabled,
          front: () => frontController.text,
          back: () => backController.text,
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isConcept,
          onChanged: enabled ? onIsConceptChanged : null,
          title: const Text('Concept card'),
          subtitle: const Text(
            'Enables Feynman mode — explain it in your own words.',
          ),
        ),
      ],
    );
  }
}
