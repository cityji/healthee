/// `.bio-bottom` — the model's terms under the hero's figure.
///
/// Split out of `bio_hero_parts.dart` at the 400-line gate (Standards §1);
/// `bio_hero_parts.dart` re-exports it, so every caller's import is unchanged.
///
/// ```css
/// .bio-bottom       { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
/// .bio-bottom span  { font-size:10px; opacity:.85; }
/// .bio-bottom strong{ font-size:17px; font-weight:600; }
/// ```
///
/// ## Two layouts, one row
///
/// A term with no [BioStat.icon] draws as the prototype's text pair. When the
/// terms carry icons, the row is the redesigned Today hero's: each term is a
/// **badge** (its icon in a soft disc of its own family's hue), then the value
/// over the label, and a hairline divides the two terms. It is the owner's
/// mockup, and it keeps `APP_DESIGN.md`'s *no card-in-card*: nothing here is a
/// container with content in it. The disc holds a glyph, the same as an icon
/// tile in a list row.
///
/// The ink is the hero's own and is a parameter: the hero has its own surface
/// in both themes, so nothing inside it may reach for the page's ink. The icon
/// hues are the app's family hues (green fitness, violet sleep), handed in by
/// the caller that knows which term is which.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/type_scale_bio.dart';
import 'package:healthee/shared/instrument/h_tap.dart';

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

/// `.bio-bottom` — the model's terms, side by side.
class BioStatsRow extends StatelessWidget {
  /// [ink] is the hero's own ink; see the library docstring.
  const BioStatsRow({
    required this.stats,
    required this.ink,
    this.centred = false,
    this.divider,
    super.key,
  });

  /// `.bio-bottom { gap: 16px }`.
  static const double spacing = 16;

  /// `.bio-bottom span { opacity: .85 }`.
  static const double labelOpacity = 0.85;

  /// The badge's disc, and the glyph inside it.
  static const double badge = 40;
  static const double glyph = 20;

  /// Between the badge and the words.
  static const double badgeGap = 10;

  /// The hairline between two badged terms, and how tall it stands.
  static const double dividerHeight = 36;

  /// The terms, in the payload's order.
  final List<BioStat> stats;

  /// The hero's ink.
  final Color ink;

  /// Whether the text-only columns are centred, under a centred card.
  ///
  /// **The value is drawn ABOVE the label, which the prototype's `.bio-bottom`
  /// does the other way round.** Two labels of different lengths — `Fitness
  /// contribution` fits one line, `Sleep duration contribution` does not at
  /// 320 — put the two figures on different baselines, which is the misalignment
  /// this fixes. Above the label, the figures line up whatever the words do,
  /// and the row reads as two small numbers under the big one.
  final bool centred;

  /// The hairline's colour between badged terms. Null draws none.
  final Color? divider;

  bool get _badged => stats.any((stat) => stat.icon != null);

  @override
  Widget build(BuildContext context) => Row(
    // Top-aligned in both layouts: a label that wraps (`Sleep duration
    // contribution` does at 390) must not push its figure off its neighbour's.
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (var i = 0; i < stats.length; i++) ...<Widget>[
        if (i > 0) ..._between(),
        Expanded(
          child: HTap(
            onTap: stats[i].onOpen,
            semanticLabel: '${stats[i].label} ${stats[i].value}',
            child: _badged ? _badgedTerm(stats[i]) : _textTerm(stats[i]),
          ),
        ),
      ],
    ],
  );

  List<Widget> _between() {
    final colour = divider;
    if (!_badged || colour == null) {
      return const <Widget>[SizedBox(width: spacing)];
    }
    return <Widget>[
      const SizedBox(width: spacing / 2),
      SizedBox(
        width: hairline,
        height: dividerHeight,
        child: ColoredBox(color: colour),
      ),
      const SizedBox(width: spacing / 2),
    ];
  }

  Widget _badgedTerm(BioStat stat) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (stat.icon case final IconData icon) ...<Widget>[
        Container(
          width: badge,
          height: badge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: stat.hueSoft ?? ink.withValues(alpha: ink.a * 0.1),
          ),
          child: Icon(icon, size: glyph, color: stat.hue ?? ink),
        ),
        const SizedBox(width: badgeGap),
      ],
      Expanded(child: _words(stat, CrossAxisAlignment.start, TextAlign.start)),
    ],
  );

  Widget _textTerm(BioStat stat) => centred
      ? _words(stat, CrossAxisAlignment.center, TextAlign.center)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _label(stat, TextAlign.start),
            _value(stat, TextAlign.start),
          ],
        );

  /// The value over the label.
  Widget _words(BioStat stat, CrossAxisAlignment cross, TextAlign align) =>
      Column(
        crossAxisAlignment: cross,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[_value(stat, align), _label(stat, align)],
      );

  Widget _value(BioStat stat, TextAlign align) => Text(
    stat.value,
    textAlign: align,
    style: BioType.bioStat.copyWith(color: ink),
  );

  Widget _label(BioStat stat, TextAlign align) => Text(
    stat.label,
    textAlign: align,
    style: BioType.bioStatLabel.copyWith(
      color: ink.withValues(alpha: ink.a * labelOpacity),
    ),
  );
}
