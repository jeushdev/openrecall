import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/app_routes.dart';
import '../../../../theme/app_geometry.dart';
import '../../../../theme/app_tokens.dart';

/// The trailing dashed-border "Create" cell in the Decks grid (ui-spec-v1 §6.1).
///
/// A convenience duplicate of the shell's centre Create button — tapping it also
/// routes to `/deck-creator`. The acceptable redundancy is called out in the
/// spec, so it isn't removed.
class CreateDeckTile extends StatelessWidget {
  const CreateDeckTile({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: tokens.borderHairline,
        radius: AppRadii.gridTile,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadii.gridTileRadius,
          onTap: () => context.push(AppRoutes.deckCreatorPath),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: tokens.textTertiary),
                const SizedBox(height: 4),
                Text(
                  'Create',
                  style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Strokes a dashed rounded-rectangle border. A [CustomPainter] rather than a
/// package dependency, and shadow-free by construction (§3.3).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + _dash), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
