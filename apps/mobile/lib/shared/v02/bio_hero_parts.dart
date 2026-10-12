/// What the biological-age figure becomes when the server refused the number.
///
/// What is left of the old bio hero's parts file: the hero itself, its halo,
/// skin and model label are gone, and only the withheld figure is still drawn
/// (`today_hero_withheld.dart` hands it to the orb hero).
///
/// **It takes the ink as a parameter, which is not a hole in the no-`Color`
/// rule.** The colour is the hero's, handed to its own part, not a hue a call
/// site chose.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/type_scale_bio.dart';
import 'package:healthee/data/honesty/last_known.dart';

/// What stands in the figure's place when the server refused the number.
///
/// Two states, and the difference between them is the whole design:
///
///   * **nothing held** — a dash at the figure's own size. The hero keeps its
///     place on the page; only the number is gone. A refused hero is still a
///     hero.
///   * **a value held from an earlier day** — the owner asked for this: *"it
///     should show the old one instead of completely not showing"*. It is drawn
///     [staleOpacity] faded, under a **dashed rule**, over a date line in full
///     ink. That is three separate signals that it is not today's, and they are
///     deliberately not all captions: this repo's most-repeated defect is a
///     stale value read as current, so the figure has to LOOK different before a
///     word is read. The dash is the same vocabulary `ValueHole` and
///     `WithheldPanel` use for absence, applied to a number that is present but
///     out of date.
///
/// The date is never truncated and never faded. It is not a footnote — it is
/// what makes drawing the figure at all legitimate, so it renders at the hero's
/// own ink, wraps rather than ellipsizes, and has no `maxLines`.
class BioWithheldFigure extends StatelessWidget {
  /// [value] is preformatted; null draws the dash. [asOf] is `YYYY-MM-DD`.
  const BioWithheldFigure({required this.ink, this.value, this.asOf, super.key})
    : assert(
        (value == null) == (asOf == null),
        'A stale figure without its date is the stale-as-current bug this '
        'widget exists to make unrepresentable; a date with no figure is a '
        'caption about nothing. Pass both, or neither.',
      );

  /// Identifies the faded figure, so a test can measure what was painted.
  static const Key staleFigureKey = ValueKey<String>('bio-hero.stale-figure');

  /// Identifies the dash drawn when nothing is held.
  static const Key holeKey = ValueKey<String>('bio-hero.no-value');

  /// Identifies the date line, so a test can prove it is on screen and whole.
  static const Key dateKey = ValueKey<String>('bio-hero.as-of');

  /// How faded a value that is no longer current is drawn.
  static const double staleOpacity = 0.55;

  /// How faint the dash is when there is nothing to show at all.
  static const double holeOpacity = 0.4;

  /// The em dash that stands where the number would be.
  static const String noValue = '—';

  /// What the date line says before the date.
  static const String asOfPrefix = 'Last known · as of ';

  /// The gap above the dashed rule, and below it.
  static const double ruleGap = 10;

  /// The dashed rule's own thickness, dash and gap.
  static const double dash = 5;

  /// The gap between one dash and the next.
  static const double dashGap = 4;

  /// The hero's ink. See the library docstring for why this is a parameter.
  final Color ink;

  /// The last value this phone held, already formatted. Null draws the dash.
  final String? value;

  /// The calendar day [value] belonged to, `YYYY-MM-DD`.
  final String? asOf;

  @override
  Widget build(BuildContext context) {
    final held = value;
    final day = asOf;
    if (held == null || day == null) {
      return Text(
        noValue,
        key: holeKey,
        style: BioType.bioAge.copyWith(
          color: ink.withValues(alpha: ink.a * holeOpacity),
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Opacity(
          opacity: staleOpacity,
          child: Text(
            held,
            key: staleFigureKey,
            style: BioType.bioAge.copyWith(color: ink),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
        const SizedBox(height: ruleGap),
        SizedBox(
          height: hairline,
          child: CustomPaint(
            painter: _DashedRule(colour: ink),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: ruleGap),
        Text(
          '$asOfPrefix${plainDay(day)}',
          key: dateKey,
          style: BioType.bioContext.copyWith(color: ink),
        ),
      ],
    );
  }
}

/// The broken rule under a value that is no longer current.
class _DashedRule extends CustomPainter {
  const _DashedRule({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.butt;
    final y = size.height / 2;
    var at = 0.0;
    while (at < size.width) {
      final end = at + BioWithheldFigure.dash;
      canvas.drawLine(
        Offset(at, y),
        Offset(end > size.width ? size.width : end, y),
        paint,
      );
      at = end + BioWithheldFigure.dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedRule oldDelegate) => oldDelegate.colour != colour;
}
