/// `Beyond a single night` — efficiency, regularity and HRV over the fortnight.
///
/// `design/mobile-preview/sleep-history-view.js`:
///
/// ```js
/// ${H.chapter('sleep-trends','Beyond a single night','sleep','insights')}
/// ${['efficiency','regularity','hrv'].map(key => H.historyPanel(key)).join('')}
/// ```
///
/// Each of those is a panel with the latest reading, a full line chart with its
/// gridlines and its touch readout, and a line saying how many dated samples are
/// behind it.
///
/// ## Straight segments, never a spline
///
/// These are **nightly** readings — one number per night, not a dense continuous
/// trace — so the line joins them and does not curve between them. A monotone
/// curve would be defensible for a heart-rate trace sampled every minute; here
/// it would draw an efficiency at 03:00 on a night that has exactly one
/// efficiency, and the rule this project already learned the expensive way is
/// that an interpolation must never produce a value nobody measured.
///
/// ## A gap stays a gap
///
/// A night the strap did not measure enters the series as `null`.
/// `SeriesPainter` breaks the line there rather than joining across it, so a
/// missing night looks missing instead of looking like a straight run.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/type_scale_keys.dart';
import 'package:healthee/data/honesty/reading.dart';
import 'package:healthee/data/honesty/sleep_gap.dart';
import 'package:healthee/data/models/sleep_night.dart';
import 'package:healthee/features/sleep/sleep_format.dart';
import 'package:healthee/shared/charts/v02/trend_dots.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/usual_range.dart';
import 'package:healthee/shared/v02/key_number_card.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// One of the three fortnight panels.
@immutable
class SleepTrend {
  /// What to draw, and where its numbers come from.
  const SleepTrend({
    required this.title,
    required this.tone,
    required this.unit,
    required this.metric,
    required this.read,
    this.digits = 0,
    this.infoKey,
    this.higherIsBetter = true,
    this.ceiling,
  });

  /// The prototype's panel title.
  final String title;

  /// Which family it belongs to.
  final Tone tone;

  /// The unit beside the figure and in the readout.
  final String unit;

  /// The metric this panel opens.
  final String metric;

  /// Pulls this trend's value off one night.
  final Reading<double> Function(SleepNight night) read;

  /// How many decimals the figure carries.
  final int digits;

  /// Which ⓘ entry belongs to it.
  final String? infoKey;

  /// Which way is better. All three are higher today.
  final bool higherIsBetter;

  /// A scale the reading cannot pass, 100 for a percentage.
  final double? ceiling;
}

/// The three, in the prototype's order.
const List<SleepTrend> kSleepTrends = <SleepTrend>[
  SleepTrend(
    title: 'Sleep efficiency',
    tone: Tone.sleep,
    unit: '%',
    metric: 'efficiency_pct',
    read: _efficiency,
    digits: 1,
    infoKey: 'sleep_health',
    ceiling: 100,
  ),
  SleepTrend(
    title: 'Sleep regularity',
    tone: Tone.sleep,
    unit: 'SRI',
    metric: 'sri',
    read: _sri,
    infoKey: 'sleep_consistency',
  ),
  SleepTrend(
    title: 'Heart-rate variability',
    tone: Tone.fitness,
    unit: 'ms',
    metric: 'hrv_sleep_avg',
    read: _hrv,
    infoKey: 'hrv',
  ),
];

Reading<double> _efficiency(SleepNight night) => night.efficiencyPct;
Reading<double> _sri(SleepNight night) => night.sri;
Reading<double> _hrv(SleepNight night) => night.hrvSleepAvg;

/// What the band, the line and a hollow dot mean, said once per card.
const String kTrendLegend =
    'Shaded: the middle half of the fortnight before. Dashed: this '
    'average. Hollow: a night outside the shaded part.';

/// One trend card: the fortnight's average, its change, and every night on
/// the owner's usual band (`proposal.js::trendCard`).
///
/// The band is `usual_range.dart`'s middle half, taken from the fourteen
/// nights before these, so a fortnight is read against the one before it and
/// never against itself. With fewer than seven earlier nights there is no band
/// and no change, and the card says it is still learning.
class SleepTrendPanel extends StatelessWidget {
  /// [recent] and [earlier] are newest first, the order `/api/sleep` sends.
  const SleepTrendPanel({
    required this.trend,
    required this.recent,
    required this.reveals,
    this.earlier = const <SleepNight>[],
    this.onDetails,
    super.key,
  });

  /// Between the figure and the chart, and around the sentence.
  static const double chartGap = 10;

  /// A change under one unit is said as none.
  static const double flat = 1;

  /// Which trend this card draws.
  final SleepTrend trend;

  /// The fortnight, newest first.
  final List<SleepNight> recent;

  /// The fortnight before it, newest first.
  final List<SleepNight> earlier;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Opens this metric's own history.
  final void Function(String metric)? onDetails;

  /// Oldest first, with an unmeasured night kept as a gap.
  List<double?> get series => <double?>[
    for (final night in recent.reversed) trend.read(night).valueOrNull,
  ];

  /// One short date per night, oldest first.
  List<String> get dates => <String>[
    for (final night in recent.reversed) shortDate(night.date),
  ];

  /// How many of those nights carry a reading.
  int get measured => series.where((value) => value != null).length;

  List<double> get _before => <double>[
    for (final night in earlier)
      if (trend.read(night).valueOrNull case final double value) value,
  ];

  /// The usual band, from the fortnight before.
  UsualRange? get band => usualRangeOf(_before);

  /// The line under the chart when there is nothing to read.
  String get note => measured == 0
      ? 'No night in the last fortnight carries this reading.'
      : '$measured ${measured == 1 ? 'night' : 'nights'} measured'
            '${dates.isEmpty ? '' : ' through ${dates.last}'}.';

  static double? _mean(Iterable<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

  String _say(double value) => value.toStringAsFixed(trend.digits);

  Verdict? _change(double? mean) {
    final before = _before;
    final then = _mean(before);
    if (mean == null || then == null || before.length < kUsualMinDays) {
      return null;
    }
    final change = mean - then;
    if (change.abs() < flat) {
      return const Verdict(
        'No change vs the fortnight before',
        VerdictTone.neutral,
      );
    }
    return Verdict(
      '${change > 0 ? '↑' : '↓'} ${change.abs().round()} vs the fortnight before',
      (change > 0) == trend.higherIsBetter
          ? VerdictTone.better
          : VerdictTone.worse,
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = series;
    final mean = _mean(<double>[for (final v in values) ?v]);
    final usual = band;
    final change = _change(mean);
    final latest = recent.isEmpty
        ? Withheld<double>(SleepGap.noSession.disclosure)
        : trend.read(recent.first);
    return Panel(
      tone: trend.tone,
      label: trend.title,
      head: PanelHead(
        title: trend.title,
        icon: SolarIconsOutline.chart_2,
        infoKey: trend.infoKey,
        actionLabel: onDetails == null ? null : 'Details',
        onAction: onDetails == null ? null : () => onDetails!(trend.metric),
      ),
      child: Builder(
        builder: (context) {
          final colors = context.colors;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PanelValue(
                mean == null ? '—' : _say(mean),
                unit: trend.unit,
                context_: measured == 0
                    ? null
                    : 'average over $measured nights',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (change case final Verdict said) VerdictChip(said),
                  Text(
                    trend.higherIsBetter
                        ? 'Higher is better.'
                        : 'Lower is better.',
                    style: KeyType.line.copyWith(color: colors.ink2),
                  ),
                ],
              ),
              const SizedBox(height: chartGap),
              RevealOnce(
                id: 'sleep.trend.${trend.metric}',
                registry: reveals,
                builder: (context, t) => TrendDots(
                  values: values,
                  progress: t,
                  band: usual,
                  average: mean,
                  digits: trend.digits,
                  ceiling: trend.ceiling,
                  captions: dates.isEmpty
                      ? const <String>[]
                      : <String>[dates.first, dates.last],
                  semanticLabel: '${trend.title} over the recent nights',
                ),
              ),
              const SizedBox(height: chartGap),
              _sentence(colors, values, usual),
              if (usual != null) const PanelNote(kTrendLegend),
              PanelNote(note),
              if (latest case Withheld<double>(:final disclosure))
                PanelNote('Latest reading: ${disclosure.message}'),
            ],
          );
        },
      ),
    );
  }

  Widget _sentence(
    HealtheeColors colors,
    List<double?> values,
    UsualRange? usual,
  ) {
    final style = KeyType.line.copyWith(color: colors.ink2);
    if (usual == null) {
      return Text(
        'Your usual range needs $kUsualMinDays measured nights before these. '
        'It is still being learned.',
        style: style,
      );
    }
    final inside = values
        .where((v) => v != null && usual.sideOf(v) == UsualSide.within)
        .length;
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(
            text: '$inside of $measured nights',
            style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink),
          ),
          TextSpan(
            text:
                ' were inside your usual of ${_say(usual.low)} to '
                '${_say(usual.high)} ${trend.unit}.',
          ),
        ],
      ),
    );
  }
}
