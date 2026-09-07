import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../decks/domain/study_mode.dart';
import 'pre_session_picker_layout.dart';

/// The pre-session mode picker (ui-spec-v1 §6.2, decided with the user).
///
/// The revamped Decks tab routes straight into `/study/:deckId` with no mode
/// choice, and the engine still stores one `study_mode` per session — so the
/// choice is made here, once, before the session is built. Same "chosen once at
/// session start" shape §6.2.1 uses for the Feynman timer. Only the modes the
/// deck structurally supports are offered.
class ModePicker extends StatelessWidget {
  const ModePicker({super.key, required this.modes, required this.onSelected});

  /// The offered modes, in [StudyMode] declaration order (Flip, Cloze, Feynman).
  final List<StudyMode> modes;
  final ValueChanged<StudyMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return PreSessionPickerLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How do you want to study this deck?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          for (final mode in modes) ...[
            _ModeButton(
              label: mode.label,
              onTap: () => onSelected(mode),
              tokens: tokens,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final VoidCallback onTap;
  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.cardFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: tokens.borderHairline,
              width: AppBorders.hairline,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
