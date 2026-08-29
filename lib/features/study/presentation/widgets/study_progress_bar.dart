import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';

/// The study session's top progress bar (ui-spec-v1 §6.2 "Shared chrome").
///
/// A `2px` hairline track with the completed fraction drawn in the fixed
/// `blue` accent fill (`#9DBDD2`) — width is `completed / total`, where a card
/// counts as complete once it is Mastered or parked (the two ways it leaves the
/// queue for good). Deliberately label-less: the old engine screen printed
/// "n / m mastered" beneath its bar; §6.2 drops that.
class StudyProgressBar extends StatelessWidget {
  const StudyProgressBar({
    super.key,
    required this.completedCount,
    required this.totalCount,
  });

  final int completedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final fraction =
        totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);

    return SizedBox(
      height: 2,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: tokens.borderHairline),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: ColoredBox(color: tokens.accent('blue').fill),
          ),
        ],
      ),
    );
  }
}
