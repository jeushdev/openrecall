import 'package:flutter/material.dart';

import '../../features/study/domain/study_session.dart';

/// Placeholder for the study session (`/study/:deckId`, ui-spec-v1 §4, §6.2).
///
/// A top-level route outside the shell — the bottom nav bar is never mounted
/// during a session (a hard requirement: the §5.1 glass bar's `BackdropFilter`
/// must never compete with the zero-network study loop for frame budget).
///
/// The `scope` query parameter maps directly to [CardScope] and defaults to
/// [CardScope.due]. The real Flip/Cloze/List/Feynman UI arrives in U5/U6; this
/// only echoes the resolved arguments so routing tests can assert them.
class StudySessionScreen extends StatelessWidget {
  const StudySessionScreen({
    super.key,
    required this.deckId,
    required this.scope,
  });

  final String deckId;
  final CardScope scope;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Study $deckId · ${scope.name}')),
    );
  }
}
