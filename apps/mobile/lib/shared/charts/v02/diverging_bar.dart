/// A correlation, drawn from zero.
///
/// The colour kit's correlation bar: it diverges from a centre tick, **moving
/// together is Strain blue, moving opposite is Activity orange**, and neither
/// is good or bad. A strong negative is not an alarm; it is a direction.
/// `r` runs −1 to +1 and a bar's length is its magnitude.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The bar.
class DivergingBar extends StatelessWidget {
  /// [r] is the correlation, clamped to −1 to +1.
  const DivergingBar({required this.r, this.height = 6, super.key});

  /// The coefficient.
  final double r;

  /// Track thickness.
  final double height;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    return SizedBox(
      height: height + 6,
      width: double.infinity,
      child: CustomPaint(
        painter: DivergingBarPainter(
          r: r.clamp(-1.0, 1.0),
          thickness: height,
          together: hues.strain,
          opposite: hues.movement,
          colors: context.colors,
        ),
      ),
    );
  }
}

/// Paints [DivergingBar].
class DivergingBarPainter extends CustomPainter {
  /// Everything it draws is given.
  DivergingBarPainter({
    required this.r,
    required this.thickness,
    required this.together,
    required this.opposite,
    required this.colors,
  });

  final double r;
  final double thickness;
  final Color together;
  final Color opposite;
  final HealtheeColors colors;

  /// The centre tick's width.
  static const double tick = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    final top = (size.height - thickness) / 2;
    final radius = Radius.circular(thickness / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, thickness),
        radius,
      ),
      Paint()..color = colors.surface2,
    );
    final length = r.abs() * mid;
    if (length > 0) {
      final rect = r > 0
          ? Rect.fromLTWH(mid, top, length, thickness)
          : Rect.fromLTWH(mid - length, top, length, thickness);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topRight: r > 0 ? radius : Radius.zero,
          bottomRight: r > 0 ? radius : Radius.zero,
          topLeft: r < 0 ? radius : Radius.zero,
          bottomLeft: r < 0 ? radius : Radius.zero,
        ),
        Paint()..color = r > 0 ? together : opposite,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(mid - tick / 2, top - 3, tick, thickness + 6),
      Paint()..color = colors.ink2,
    );
  }

  @override
  bool shouldRepaint(DivergingBarPainter old) =>
      old.r != r ||
      old.together != together ||
      old.opposite != opposite ||
      old.colors != colors;
}
