import 'package:flutter/material.dart';

import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';
import '../../../courses/domain/course.dart';

const _courseLabelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

/// Single-select row of course chips for the Deck Creator (ui-spec-v1 §4).
///
/// Reuses the Mastery-tab course-rollup chip language (§6.3): a card-fill
/// container with a 4px left-edge accent bar in the course's [AppTokens.accent]
/// fill. The selected chip swaps its hairline border for the accent's text
/// colour and shows a check — no shadow, per §3.3.
class CourseSelector extends StatelessWidget {
  const CourseSelector({
    super.key,
    required this.courses,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Course> courses;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  static const double _chipWidth = 148;
  static const double _chipHeight = 56;
  static const double _labelWidth = _chipWidth - 4 - 20 - 22;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    if (courses.isEmpty) {
      return Text(
        'No courses yet.',
        style: TextStyle(fontSize: 13, color: tokens.textSecondary),
      );
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final labelStyle = DefaultTextStyle.of(context).style
        .merge(_courseLabelStyle);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChipWidth =
            constraints.hasBoundedWidth && constraints.maxWidth > _chipWidth
            ? constraints.maxWidth
            : _chipWidth;
        final chipWidths = <double>[];
        var requiredHeight = _chipHeight;

        for (final course in courses) {
          final painter = TextPainter(
            text: TextSpan(text: course.name, style: labelStyle),
            textScaler: textScaler,
            textDirection: textDirection,
          )..layout();
          final width = (painter.width + (_chipWidth - _labelWidth))
              .clamp(_chipWidth, maxChipWidth)
              .toDouble();
          painter.layout(maxWidth: width - (_chipWidth - _labelWidth));
          chipWidths.add(width);
          if (painter.height + 16 > requiredHeight) {
            requiredHeight = painter.height + 16;
          }
        }

        return SizedBox(
          height: requiredHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: courses.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final course = courses[i];
              return _CourseChip(
                course: course,
                selected: course.id == selectedId,
                width: chipWidths[i],
                onTap: () => onSelected(course.id),
              );
            },
          ),
        );
      },
    );
  }
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({
    required this.course,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final Course course;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final accent = tokens.accent(course.accentColor);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: tokens.cardFill,
        borderRadius: AppRadii.gridTileRadius,
        border: Border.all(
          color: selected ? accent.text : tokens.borderHairline,
          width: AppBorders.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent.fill),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.name,
                          style: _courseLabelStyle.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        child: selected
                            ? Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: accent.text,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
