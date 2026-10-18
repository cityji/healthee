/// The plan: four items, each with a time, a pattern and a reason built only
/// from the owner's own data.
library;

import 'package:healthee/data/basics/breathing/breathing_pattern.dart';
import 'package:meta/meta.dart';

/// The four slots of the plan.
enum BreathingItemKind {
  /// After waking.
  morning('Morning', 5, 1004),

  /// An afternoon reset.
  midday('Midday', 4, 1005),

  /// After the owner's free time in the evening.
  night('Night', 10, 1006),

  /// For nights with high stress while awake. No reminder.
  onDemand('If you wake', 5, null);

  const BreathingItemKind(this.label, this.minutes, this.reminderId);

  /// The name on the plan.
  final String label;

  /// Planned minutes.
  final int minutes;

  /// The local-notification id, or null when the item has no reminder.
  final int? reminderId;

  /// The pattern used until the owner picks another.
  BreathPattern get defaultPattern => switch (this) {
    morning => kSteady,
    midday => kBox,
    night || onDemand => kLongExhale,
  };

  /// Whether the item counts toward the minutes a day and has a reminder.
  bool get isScheduled => reminderId != null;
}

/// One item of the plan.
@immutable
class BreathingItem {
  /// An item. Built by `buildBreathingPlan`.
  const BreathingItem({
    required this.kind,
    required this.minuteOfDay,
    required this.minutes,
    required this.pattern,
    required this.enabled,
    required this.reason,
    this.timeIsDefault = false,
  });

  /// Which slot.
  final BreathingItemKind kind;

  /// Local clock minute of the reminder, or null for on demand.
  final int? minuteOfDay;

  /// Planned minutes.
  final int minutes;

  /// The pattern to breathe.
  final BreathPattern pattern;

  /// Whether the owner has it on.
  final bool enabled;

  /// A sentence or two built only from real values; says so when data is thin.
  final String reason;

  /// True when the time is the owner's default because the data was too thin.
  final bool timeIsDefault;
}

/// The whole plan.
@immutable
class BreathingPlan {
  /// A plan of [items] in display order.
  const BreathingPlan(this.items);

  /// Morning, midday, night, then on demand when it applies.
  final List<BreathingItem> items;

  /// The item for [kind], or null when it is absent from the plan.
  BreathingItem? item(BreathingItemKind kind) {
    for (final item in items) {
      if (item.kind == kind) return item;
    }
    return null;
  }

  /// Minutes a day: the enabled scheduled items. On demand is not counted.
  int get totalMinutesPerDay => items
      .where((item) => item.enabled && item.kind.isScheduled)
      .fold(0, (sum, item) => sum + item.minutes);
}
