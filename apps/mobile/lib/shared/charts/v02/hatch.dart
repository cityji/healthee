/// The look of a reading that is not there: diagonal hatch, never a colour.
///
/// The colour kit's no-data rule: missing data is hatched grey with a dash, a
/// gap stays a gap, and nothing is interpolated or coloured. This is the one
/// painter for it, so a chip, a bar and a sparkline slot cannot each invent
/// their own idea of "empty".
library;

import 'package:flutter/material.dart';

/// Fills [rect] (clipped to [radius]) with diagonal lines in [ink].
void paintHatch(
  Canvas canvas,
  Rect rect, {
  required Color ink,
  double radius = 3,
  double gap = 4,
  double stroke = 1,
}) {
  canvas
    ..save()
    ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  final paint = Paint()
    ..color = ink
    ..strokeWidth = stroke;
  for (var x = rect.left - rect.height; x < rect.right; x += gap) {
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(x + rect.height, rect.top),
      paint,
    );
  }
  canvas.restore();
}
