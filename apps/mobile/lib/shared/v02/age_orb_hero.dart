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
import 'package:healthee/shared/v02/instruments/age_orb.dart';
import 'package:healthee/shared/v02/key_number_card.dart';
import 'package:solar_icons/solar_icons.dart';

/// The hero's title, WHOOP's uppercase label.
const String kAgeOrbTitle = 'BIOLOGICAL AGE';

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
    this.turning = true,
    this.paused = false,
    super.key,
  });

  /// Side padding; the hero is edge to edge.
  static const double side = 20;

  /// The orb's share of the width, and its largest size.
  static const double orbShare = 0.74;
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

  /// Whether the orb turns. Off for a withheld number.
  final bool turning;

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
                final d = (box.maxWidth * orbShare).clamp(180.0, orbMax);
                return Center(
                  child: AgeOrb(
                    diameter: d,
                    turning: turning,
                    child: _figure(colors, d),
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

  Widget _figure(HealtheeColors colors, double diameter) => paused
      ? Semantics(
          label: 'Biological age estimate paused',
          child: const SizedBox.shrink(),
        )
      : _number(colors, diameter);

  Widget _number(HealtheeColors colors, double diameter) => Semantics(
    label: 'Biological age $value years',
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: KeyType.value.copyWith(
              color: colors.ink,
              fontSize: diameter * 0.24,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text('YEARS', style: _caps.copyWith(color: colors.ink2)),
          if (verdict case final Verdict said) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              said.words,
              style: KeyType.name.copyWith(
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
