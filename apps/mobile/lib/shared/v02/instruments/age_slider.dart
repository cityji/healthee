/// Your biological age against your actual age, as one dense tick slider in
/// the style of WHOOP's `Pace of Aging`: many thin ticks that brighten near
/// the needle, the needle at the estimate, and a small mark at your actual age.
///
/// The scale runs eight years either side of your actual age, widened to keep
/// the estimate on it. `Younger` sits on the left and `Older` on the right.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale_keys.dart';

/// Years either side of the actual age.
const double kAgeSliderSpan = 8;

/// Ticks across the track.
const int kAgeSliderTicks = 64;

/// The slider.
class AgeSlider extends StatelessWidget {
  const AgeSlider({
    required this.estimate,
    required this.actual,
    this.progress = 1,
    super.key,
  });

  /// Identifies the plot for tests.
  static const Key plotKey = ValueKey<String>('age-slider-plot');

  /// The track's height, and the labels' under it.
  static const double height = 58;

  final double estimate;
  final double actual;

  /// 0 to 1 from the reveal: the needle slides in from the actual age.
  final double progress;

  /// The scale's ends.
  (double, double) get range {
    var low = actual - kAgeSliderSpan;
    var high = actual + kAgeSliderSpan;
    if (estimate < low + 1) {
      low = (estimate - 1).floorToDouble();
    }
    if (estimate > high - 1) {
      high = (estimate + 1).ceilToDouble();
    }
    return (low, high);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (low, high) = range;
    final shown = actual + (estimate - actual) * progress.clamp(0, 1);
    String year(double v) =>
        v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    return Semantics(
      label:
          'Biological age ${year(estimate)} on a scale from ${year(low)} to '
          '${year(high)}. Your actual age is ${year(actual)}.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            key: plotKey,
            painter: _SliderPainter(
              low: low,
              high: high,
              value: shown,
              actual: actual,
              ink: colors.ink,
              faint: colors.ink3,
              labels: (year(low), '${year(actual)} · your age', year(high)),
              labelInk: colors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.low,
    required this.high,
    required this.value,
    required this.actual,
    required this.ink,
    required this.faint,
    required this.labels,
    required this.labelInk,
  });

  final double low;
  final double high;
  final double value;
  final double actual;
  final Color ink;
  final Color faint;
  final (String, String, String) labels;
  final Color labelInk;

  static const double trackTop = 8;
  static const double tickHeight = 24;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double v) => (v - low) / (high - low) * size.width;
    final needle = x(value);
    final step = size.width / (kAgeSliderTicks - 1);
    for (var i = 0; i < kAgeSliderTicks; i++) {
      final at = i * step;
      final near = (at - needle).abs() / (size.width * 0.07);
      final lift = 1 / (1 + near * near);
      final alpha = 0.16 + (i.isEven ? 0.08 : 0) + 0.7 * lift;
      canvas.drawLine(
        Offset(at, trackTop + 2),
        Offset(at, trackTop + tickHeight - 2),
        Paint()
          ..color = (lift > 0.5 ? ink : faint).withValues(alpha: alpha)
          ..strokeWidth = 1.4,
      );
    }
    // Your actual age: a small triangle under the track.
    final you = x(actual);
    canvas.drawPath(
      Path()
        ..moveTo(you, trackTop + tickHeight + 2)
        ..lineTo(you - 4, trackTop + tickHeight + 8)
        ..lineTo(you + 4, trackTop + tickHeight + 8)
        ..close(),
      Paint()..color = faint,
    );
    // The needle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(needle, trackTop + tickHeight / 2),
          width: 3,
          height: tickHeight + 12,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = ink,
    );
    final y = size.height - 8;
    _text(canvas, labels.$1, Offset(0, y), 0);
    _text(canvas, labels.$2, Offset(you, y), 0.5);
    _text(canvas, labels.$3, Offset(size.width, y), 1);
  }

  void _text(Canvas canvas, String text, Offset at, double anchor) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: KeyType.rangeEnd.copyWith(color: labelInk),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(at.dx - painter.width * anchor, at.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.value != value ||
      old.low != low ||
      old.high != high ||
      old.ink != ink ||
      old.labelInk != labelInk;
}
