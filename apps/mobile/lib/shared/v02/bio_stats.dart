/// One of the model's terms under the biological-age figure.
///
/// The row that used to draw these (`BioStatsRow`) went with the old bio hero;
/// `AgeOrbHero` draws them now, and this file keeps only the value it is handed.
library;

import 'package:flutter/material.dart';

/// One of the statistics under the hero's figure.
@immutable
class BioStat {
  /// Builds a statistic: a small [label] with a larger [value].
  const BioStat(
    this.label,
    this.value, {
    this.onOpen,
    this.icon,
    this.hue,
    this.hueSoft,
  });

  /// `.bio-bottom span`.
  final String label;

  /// `.bio-bottom strong`.
  final String value;

  /// Where this term goes. `.bio-bottom > a` — both terms are anchors in the
  /// prototype, one to `#fitness` and one to `#sleep`. Null draws the term with
  /// no tap rather than a control that leads nowhere.
  final VoidCallback? onOpen;

  /// The term's family glyph. Null draws the plain text pair.
  final IconData? icon;

  /// The glyph's colour, and the disc behind it. Both required with [icon].
  final Color? hue;
  final Color? hueSoft;
}
