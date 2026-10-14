/// Today's biological-age hero in the WHOOP Healthspan layout the owner asked
/// for: no card, the page itself as the ground, a centred title, the orb with
/// the figure inside it, a tick slider against the actual age, and the
/// model's contributions as two figures under it.
///
/// It is layout only. The figure, the sentence and the contributions are the
/// caller's (`today_hero.dart`), and the model line and caveats go behind the
/// ⓘ exactly as they did on the card this replaces: the hero reads the
/// `CaveatScope` it is given and routes it into that one sheet.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_ladder.dart';
import 'package:healthee/core/theme/type_scale_keys.dart';
import 'package:healthee/data/honesty/disclosure.dart';
import 'package:healthee/shared/instrument/h_tap.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/states/caveat_scope.dart';
import 'package:healthee/shared/v02/bio_stats.dart';
import 'package:healthee/shared/v02/instruments/age_sphere.dart';
import 'package:healthee/shared/v02/key_number_card.dart';
import 'package:solar_icons/solar_icons.dart';

/// The hero's title, WHOOP's uppercase label.
const String kAgeOrbTitle = 'BIOLOGICAL AGE';

/// The sphere's radius as a share of its canvas.
const double _radiusShare = 0.425;

/// The widest the figure may paint, in radii; wider is scaled down.
const double _figureRadii = 1.4;

/// The sphere's centre and the half width it paints, for the dots to clear.
///
/// Shared by Today's hero and the biological-age screen, so the two draw the
/// same figure. The number is measured at the current text scale and, when
/// wider than 1.4 R, scaled down to that width so a large text scale never
/// clips. [paused] draws no figure and no verdict, only the spoken state.
({Widget centre, double halfWidth}) ageOrbCentre(
  BuildContext context,
  HealtheeColors colors, {
  required double canvas,
  required String value,
  required bool paused,
  Verdict? verdict,
}) {
  if (paused) {
    return (
      centre: Semantics(
        label: 'Biological age estimate paused',
        child: const SizedBox.shrink(),
      ),
      halfWidth: 0,
    );
  }
  final style = TypeLadder.display.copyWith(color: colors.ink);
  final limit = canvas * _radiusShare * _figureRadii;
  final measured = TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final wide = measured.width;
  measured.dispose();
  final painted = math.min(wide, limit);
  final centre = Semantics(
    label: 'Biological age $value years',
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: style, maxLines: 1),
            ),
            if (verdict case final Verdict said) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                said.words,
                textAlign: TextAlign.center,
                style: TypeLadder.bodyStrong.copyWith(
                  color: switch (said.tone) {
                    VerdictTone.better => colors.fav,
                    VerdictTone.worse => colors.unf,
                    VerdictTone.neutral => colors.ink2,
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return (centre: centre, halfWidth: painted / 2);
}

/// The hero.
class AgeOrbHero extends StatelessWidget {
  const AgeOrbHero({
    required this.value,
    this.verdict,
    this.subtitle,
    this.below,
    this.infoKey = 'biological_age',
    this.modelLabel,
    this.extraDisclosures = const <Disclosure>[],
    this.disclosuresLabel,
    this.onOpen,
    this.openSemantics,
    this.slider,
    this.stats = const <BioStat>[],
    this.paused = false,
    super.key,
  });

  /// Side padding; the hero is edge to edge.
  static const double side = 20;

  /// The sphere's canvas: 300 on Today, less on a narrower screen.
  static const double orbMax = 300;

  /// The figure, `34.3`. Also what a screen reader hears.
  final String value;

  /// Under the figure: `1.7 years younger`, coloured by which side it is.
  final Verdict? verdict;

  /// Under the title.
  final String? subtitle;

  /// Drawn under the orb, for a hero whose number is withheld: the reason, in
  /// the caller's own widget.
  final Widget? below;

  /// Whether the number is paused. The orb then holds nothing: no figure, no
  /// `YEARS`, and a screen reader hears that the estimate is paused rather than
  /// a number.
  final bool paused;

  final String infoKey;

  /// The model line, behind the ⓘ.
  final String? modelLabel;

  /// Disclosures the caller adds to the scope's, behind the ⓘ.
  final List<Disclosure> extraDisclosures;
  final String? disclosuresLabel;

  /// Where the arrow goes: the calculation behind the figure.
  final VoidCallback? onOpen;
  final String? openSemantics;

  /// The age against the actual age.
  final Widget? slider;

  /// The model's contributions.
  final List<BioStat> stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scope = CaveatScope.of(context);
    final disclosed = <Disclosure>[...?scope?.caveats, ...extraDisclosures];
    return CaveatScope(
      caveats: const <Disclosure>[],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(side, 4, side, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _head(colors, disclosed, scope?.label),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, box) {
                final canvas = math.min(orbMax, box.maxWidth);
                final figure = ageOrbCentre(
                  context,
                  colors,
                  canvas: canvas,
                  value: value,
                  verdict: verdict,
                  paused: paused,
                );
                return Center(
                  child: AgeSphere(
                    canvas: canvas,
                    withheld: paused,
                    clearHalfWidth: figure.halfWidth,
                    centre: figure.centre,
                  ),
                );
              },
            ),
            if (below case final Widget notice) ...<Widget>[
              const SizedBox(height: 14),
              notice,
            ],
            if (slider case final Widget scale) ...<Widget>[
              const SizedBox(height: 18),
              Text(
                'AGAINST YOUR AGE',
                style: _caps.copyWith(color: colors.ink2),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text('Younger', style: _side.copyWith(color: colors.ink2)),
                  const Spacer(),
                  Text('Older', style: _side.copyWith(color: colors.ink2)),
                ],
              ),
              scale,
            ],
            if (stats.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              _stats(colors),
            ],
          ],
        ),
      ),
    );
  }

  static final TextStyle _caps = KeyType.chip.copyWith(
    fontSize: 11.5,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
  );
  static final TextStyle _side = KeyType.line.copyWith(fontSize: 12.5);

  Widget _head(
    HealtheeColors colors,
    List<Disclosure> disclosed,
    String? label,
  ) => Row(
    children: <Widget>[
      const SizedBox(width: 56),
      Expanded(
        child: Column(
          children: <Widget>[
            Text(
              kAgeOrbTitle,
              style: _caps.copyWith(color: colors.ink, fontSize: 13),
            ),
            if (subtitle case final String line) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                line,
                textAlign: TextAlign.center,
                style: KeyType.rangeEnd.copyWith(
                  color: colors.ink2,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      SizedBox(
        width: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            MetricInfoDot(
              infoKey,
              ink: colors.ink2,
              detail: MetricDetail(
                source: modelLabel,
                disclosures: disclosed,
                disclosuresLabel: label ?? disclosuresLabel,
              ),
            ),
            if (onOpen != null) ...<Widget>[
              const SizedBox(width: 10),
              HTap(
                onTap: onOpen,
                semanticLabel: openSemantics ?? 'Biological age',
                child: Icon(
                  SolarIconsOutline.arrowRight,
                  size: 18,
                  color: colors.ink2,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _stats(HealtheeColors colors) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < stats.length; i++) ...<Widget>[
          if (i > 0)
            VerticalDivider(width: 1, thickness: 1, color: colors.line),
          Expanded(child: _stat(colors, stats[i])),
        ],
      ],
    ),
  );

  Widget _stat(HealtheeColors colors, BioStat stat) {
    final years = stat.value.trim();
    final tone = years.startsWith('−')
        ? colors.fav
        : years.startsWith('+')
        ? colors.unf
        : colors.ink;
    return HTap(
      onTap: stat.onOpen,
      semanticLabel: '${stat.label}: ${stat.value}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            Text(
              stat.value,
              style: KeyType.name.copyWith(fontSize: 20, color: tone),
            ),
            const SizedBox(height: 4),
            Text(
              stat.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TypeLadder.label.copyWith(color: colors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}
