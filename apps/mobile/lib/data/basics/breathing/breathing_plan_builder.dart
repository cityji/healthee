/// Builds the plan. Pure: every input is an argument, nothing is read here.
///
/// Every sentence in a reason is made from a value computed from the owner's
/// data. When the data is too thin the sentence says so and claims nothing.
library;

import 'package:healthee/data/basics/breathing/breathing_history.dart';
import 'package:healthee/data/basics/breathing/breathing_plan.dart';
import 'package:healthee/data/basics/breathing/breathing_settings.dart';
import 'package:healthee/data/basics/breathing/breathing_timing.dart';
import 'package:healthee/shared/usual_range.dart';
import 'package:healthee/shared/v02/reading_state.dart';

/// Night stress at or above this puts the on-demand item in the plan.
const double kOnDemandStress = 30;

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The plan as of [now].
///
/// [hrv] is the latest overnight HRV and [hrvUsual] its usual range from the
/// server card; either missing drops the HRV sentence.
BreathingPlan buildBreathingPlan({
  required DateTime now,
  required BreathingHistory history,
  required BreathingSettings settings,
  double? hrv,
  UsualRange? hrvUsual,
}) {
  final onDemand = _onDemand(now, history, settings);
  return BreathingPlan([
    _morning(history, settings, hrv, hrvUsual),
    _midday(settings),
    _night(history, settings),
    ?onDemand,
  ]);
}

BreathingItem _item(
  BreathingSettings settings,
  BreathingItemKind kind, {
  required int? minute,
  required String reason,
  bool timeIsDefault = false,
}) => BreathingItem(
  kind: kind,
  minuteOfDay: minute,
  minutes: kind.minutes,
  pattern: settings.patternFor(kind),
  enabled: settings.isEnabled(kind),
  reason: reason,
  timeIsDefault: timeIsDefault,
);

BreathingItem _morning(
  BreathingHistory history,
  BreathingSettings settings,
  double? hrv,
  UsualRange? usual,
) {
  final median = medianWakeMinute([
    for (final night in history.nights.take(kPlanNights))
      night.wake.hour * 60 + night.wake.minute,
  ]);
  final lead = median == null
      ? 'Not enough nights yet to time this.'
      : 'You wake around ${formatClock(median, meridiem: false)}.';
  final second = _hrvSentence(hrv, usual);
  return _item(
    settings,
    BreathingItemKind.morning,
    minute: median == null
        ? settings.morningDefaultMinute
        : firstQuarterHourAfter(median),
    timeIsDefault: median == null,
    reason: second == null ? lead : '$lead $second',
  );
}

String? _hrvSentence(double? hrv, UsualRange? usual) {
  if (hrv == null || usual == null || !hrv.isFinite) return null;
  final verdict = judge(
    value: hrv,
    usual: usual,
    polarity: Polarity.higherBetter,
  );
  final range = '${usual.low.round()} to ${usual.high.round()}';
  final value = hrv.toStringAsFixed(1);
  switch (verdict.state) {
    case ReadingState.better:
      final near = hrv - usual.high <= (usual.high - usual.low) * 0.1;
      return 'This morning HRV was $value, ${near ? 'just ' : ''}over your usual $range.';
    case ReadingState.worse:
      final near = usual.low - hrv <= (usual.high - usual.low) * 0.1;
      return 'This morning HRV was $value, ${near ? 'just ' : ''}under your usual $range.';
    case ReadingState.usual:
      return 'This morning HRV was $value, within your usual $range.';
    case ReadingState.watch || ReadingState.noData:
      return null;
  }
}

BreathingItem _midday(BreathingSettings settings) {
  final pattern = settings.patternFor(BreathingItemKind.midday);
  return _item(
    settings,
    BreathingItemKind.midday,
    minute: 840,
    reason: pattern.evidence.isCited
        ? 'An afternoon reset.'
        : 'An afternoon reset. Not in our evidence base, '
              'so keep it only if it helps you.',
  );
}

BreathingItem _night(BreathingHistory history, BreathingSettings settings) {
  final range = lightsOutRange([
    for (final night in history.nights.take(kPlanNights))
      night.onset.hour * 60 + night.onset.minute,
  ]);
  final reason = range == null
      ? 'Right after your free time.'
      : 'Right after your free time. Lights-out swung from '
            '${formatClock(range.earliest)} to ${formatClock(range.latest)} '
            'over ${range.nights} nights. '
            'This gives the night one fixed point.';
  return _item(
    settings,
    BreathingItemKind.night,
    minute: settings.nightFreeFromMinute,
    reason: reason,
  );
}

BreathingItem? _onDemand(
  DateTime now,
  BreathingHistory history,
  BreathingSettings settings,
) {
  final since = now.subtract(const Duration(days: kStressDays));
  StressSample? peak;
  for (final sample in history.stress) {
    final at = sample.at;
    if (at.isBefore(since) || at.isAfter(now) || at.hour >= 6) continue;
    if (!sample.value.isFinite || sample.value < kOnDemandStress) continue;
    if (peak == null || sample.value >= peak.value) peak = sample;
  }
  if (peak == null) return null;
  final hourStart = DateTime(
    peak.at.year,
    peak.at.month,
    peak.at.day,
    peak.at.hour,
  );
  final hourEnd = hourStart.add(const Duration(hours: 1));
  final awake = history.awake.any((span) => span.overlaps(hourStart, hourEnd));
  final hour = peak.at.hour;
  final from = hour == 0 ? 12 : hour;
  final to = hour + 1;
  final reason =
      'Stress hit ${peak.value.round()} between $from and $to am '
      '${_dayWord(now, peak.at)}${awake ? ' while you lay awake' : ''}. '
      'No reminder, open it from the lock screen.';
  return _item(
    settings,
    BreathingItemKind.onDemand,
    minute: null,
    reason: reason,
  );
}

String _dayWord(DateTime now, DateTime at) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final ago = today.difference(day).inHours ~/ 24;
  if (ago == 0) return 'this morning';
  if (ago == 1) return 'yesterday';
  return 'on ${_weekdays[day.weekday - 1]}';
}
