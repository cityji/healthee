/// The redesign's type: the three key numbers, the range bar and the verdict.
///
/// Transcribed from `design/mobile-preview/proposal.css`, the HTML design the
/// owner approved, the same way `type_scale.dart` transcribes `richer.css`.
/// Colourless, like every style in the scale: the tone supplies the colour.
///
/// ```text
///   key name       14px  700        .p-key-name
///   key value      44px  700  -1.8  .p-key-value
///   key unit       14px  500        .p-key-value small
///   key line       13px  400        .p-key-line, line-height 1.45
///   verdict chip   11.5  700        .p-chip
///   range ends     10.5  400        .p-range-ends (the usual label is 600)
/// ```
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/typography.dart';

TextStyle _style(
  double size,
  FontWeight weight, {
  double height = 1.4,
  double tracking = 0,
}) => TextStyle(
  fontFamily: healtheeFontFamily,
  fontFamilyFallback: healtheeFontFallback,
  fontSize: size,
  fontWeight: weight,
  // Figtree is variable: drive the wght axis, not only the weight slot.
  fontVariations: <FontVariation>[
    FontVariation('wght', weight.value.toDouble()),
  ],
  height: height,
  letterSpacing: tracking,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// The key-number cards and the range bar. Colourless; see the docstring.
abstract final class KeyType {
  /// `.p-key-name` — Recovery, Sleep, Movement.
  static final TextStyle name = _style(14, FontWeight.w700);

  /// `.p-key-value` — the reading.
  static final TextStyle value = _style(
    44,
    FontWeight.w700,
    height: 1.05,
    tracking: -1.8,
  );

  /// `.p-key-value small` — its unit.
  static final TextStyle unit = _style(14, FontWeight.w500);

  /// `.p-key-line` — the sentence that reads the reading.
  static final TextStyle line = _style(13, FontWeight.w400, height: 1.45);

  /// `.p-chip` — the verdict in words.
  static final TextStyle chip = _style(11.5, FontWeight.w700, height: 1.2);

  /// `.p-range-ends` — the track's two ends.
  static final TextStyle rangeEnd = _style(10.5, FontWeight.w400, height: 1.2);

  /// `.p-range-usual` — the usual range, named under its band.
  static final TextStyle rangeUsual = _style(
    10.5,
    FontWeight.w600,
    height: 1.2,
  );
}
