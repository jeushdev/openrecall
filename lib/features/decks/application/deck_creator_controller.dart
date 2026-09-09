import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deck_providers.dart';

/// The Deck Creator form's local state (ui-spec-v1 §4).
@immutable
class DeckCreatorState {
  const DeckCreatorState({
    this.name = '',
    this.selectedCourseId,
    this.isSubmitting = false,
    this.error,
  });

  final String name;
  final String? selectedCourseId;
  final bool isSubmitting;

  /// Set when the create call failed; shown inline, cleared on the next edit.
  final String? error;

  /// "Create" is enabled with a non-blank name and no write in flight. A course
  /// is optional: when the list is available the user picks one, but offline —
  /// where the course mirror may be empty and no picker renders — the deck is
  /// created with no course and both [CacheFirstDeckRepository.createDeck] and
  /// the `decks_fill_default_course` trigger route it to the default course.
  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;

  DeckCreatorState copyWith({
    String? name,
    String? Function()? selectedCourseId,
    bool? isSubmitting,
    String? Function()? error,
  }) {
    return DeckCreatorState(
      name: name ?? this.name,
      selectedCourseId: selectedCourseId != null
          ? selectedCourseId()
          : this.selectedCourseId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error != null ? error() : this.error,
    );
  }
}

/// Drives the Deck Creator form. `autoDispose` so the form resets every time the
/// screen is opened — the opposite of [SessionController], which is deliberately
/// kept alive across navigation.
final deckCreatorControllerProvider =
    NotifierProvider.autoDispose<DeckCreatorController, DeckCreatorState>(
      DeckCreatorController.new,
    );

class DeckCreatorController extends Notifier<DeckCreatorState> {
  @override
  DeckCreatorState build() => const DeckCreatorState();

  void nameChanged(String value) {
    state = state.copyWith(name: value, error: () => null);
  }

  void courseSelected(String courseId) {
    state = state.copyWith(selectedCourseId: () => courseId, error: () => null);
  }

  /// Creates the deck via [DecksController] (which invalidates `decksProvider`).
  /// Returns the new deck's id on success — the screen navigates straight to Add
  /// Card for it — or `null` on failure, leaving a [DeckCreatorState.error] for
  /// the screen to show and re-enabling the form.
  Future<String?> submit() async {
    if (!state.canSubmit) return null;
    state = state.copyWith(isSubmitting: true, error: () => null);

    final deck = await ref
        .read(decksControllerProvider.notifier)
        .createDeck(state.name.trim(), courseId: state.selectedCourseId);

    if (deck != null) return deck.id;

    state = state.copyWith(
      isSubmitting: false,
      error: () => "Couldn't create the deck, try again.",
    );
    return null;
  }
}
