import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'deck_segment.dart';
import 'mock/mock_decks.dart';
import 'widgets/deck_grid.dart';
import 'widgets/deck_segmented_control.dart';

/// The Decks tab (`/decks`, ui-spec-v1 §6.1) — the app's home screen.
///
/// A "Decks" header, a Due / All segmented control with its consequence-signalling
/// caption, then a 2-column grid of square deck tiles. Switching segments only
/// swaps each tile's trailing badge; the deck list and its order are unaffected.
///
/// Milestone U4 is UI-only: the grid renders against [sampleMockDecks], and
/// nothing here navigates into a study session yet.
class DecksTabScreen extends StatefulWidget {
  const DecksTabScreen({super.key});

  @override
  State<DecksTabScreen> createState() => _DecksTabScreenState();
}

class _DecksTabScreenState extends State<DecksTabScreen> {
  DeckSegment _segment = DeckSegment.due;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Decks',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DeckSegmentedControl(
                value: _segment,
                onChanged: (segment) => setState(() => _segment = segment),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Due reviews what's due today · All studies the whole deck, "
                "including cards you've mastered.",
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: tokens.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DeckGrid(decks: sampleMockDecks, segment: _segment),
            ),
          ],
        ),
      ),
    );
  }
}
