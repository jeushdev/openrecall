import 'package:flutter/material.dart';

import '../../domain/study_mode.dart';

/// The study-mode buttons on the Deck Overview (docs/spec-v3-card-model.md).
///
/// Every mode is always shown; a mode the deck has no qualifying card for is
/// rendered disabled with a caption, so it's clear the option exists but needs
/// the right kind of card. [onStart] launches a session for whichever mode is
/// tapped.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.available,
    required this.onStart,
  });

  /// The modes the deck structurally supports (from [availableModes]).
  final Set<StudyMode> available;

  final ValueChanged<StudyMode> onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Study modes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final mode in StudyMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ModeButton(
              mode: mode,
              enabled: available.contains(mode),
              onPressed: () => onStart(mode),
            ),
          ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.enabled,
    required this.onPressed,
  });

  final StudyMode mode;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonal(
          onPressed: enabled ? onPressed : null,
          child: Text(mode.label),
        ),
        if (!enabled)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(
              'No cards support this yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}
