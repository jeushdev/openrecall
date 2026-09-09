import 'package:flutter/material.dart';

/// A thin progress bar + percentage for a deck's mastery (spec §2).
///
/// Until the session engine (milestone 6) moves `mastery_level`, this reads 0
/// for every fresh deck — expected, not a bug.
class MasteryBar extends StatelessWidget {
  const MasteryBar({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: percent / 100, minHeight: 6),
          ),
        ),
        const SizedBox(width: 8),
        Text('$percent%', style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
