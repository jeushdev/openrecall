import 'package:flutter/material.dart';

import '../../domain/keyword_validator.dart';

/// The three content fields shared by the add-card form and the edit-card
/// dialog (spec §3): Front, Back (one line or many), and an optional Keyword.
///
/// Wrap in a [Form] and supply the controllers. The keyword is validated
/// against the current front/back text via [keywordError].
class CardFields extends StatelessWidget {
  const CardFields({
    super.key,
    required this.frontController,
    required this.backController,
    required this.keywordController,
    required this.enabled,
  });

  final TextEditingController frontController;
  final TextEditingController backController;
  final TextEditingController keywordController;
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
            helperText: 'One line, or one point per line for List / Feynman.',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the back of the card.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: keywordController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Keyword (optional)',
            helperText: 'A single word from the front or back, for Cloze mode.',
            border: OutlineInputBorder(),
          ),
          validator: (v) => keywordError(
            v ?? '',
            front: frontController.text,
            back: backController.text,
          ),
        ),
      ],
    );
  }
}
