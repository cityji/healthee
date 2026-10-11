/// Today's age card without its frame: no edge, no rule, and the model's terms
/// as badges divided by a hairline — the owner's mockup, in both themes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/bio_hero.dart';
import 'package:healthee/shared/v02/bio_hero_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Invented numbers, in the payload's own shape.
BiologicalAge _age({
  List<String> terms = const <String>['fitness', 'sleep duration'],
}) => BiologicalAge.maybe(<String, Object?>{
  'biological_age': 28.3,
  'chronological_age': 26,
  'delta_years': 2.3,
  'contributions': <Map<String, Object?>>[
    for (final term in terms)
      <String, Object?>{'term': term, 'delta_years': 1.1},
  ],
  'disclaimer': 'Motivational estimate from population data',
})!;

Widget _host(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: SingleChildScrollView(child: SizedBox(width: 390, child: child)),
  ),
);

ShapeBorder _shapeOf(WidgetTester tester, Finder hero) {
  final container = tester.widget<Container>(
    find.descendant(of: hero, matching: find.byType(Container)).first,
  );
  return (container.decoration! as ShapeDecoration).shape;
}

void main() {
  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('Today\'s hero has no edge and no rule — ${theme.key}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TodayBioHero(age: _age(), reveals: RevealRegistry()),
          theme.value,
        ),
      );
      final hero = find.byType(BioHero);
      final shape = _shapeOf(tester, hero) as OutlinedBorder;
      expect(shape.side, BorderSide.none);
      // The only hairline left is the upright divider between the two terms:
      // no full-width rule runs across the card.
      final rules = tester
          .widgetList<SizedBox>(
            find.descendant(of: hero, matching: find.byType(SizedBox)),
          )
          .where((box) => box.child is ColoredBox);
      expect(rules, hasLength(1));
      expect(rules.single.width, hairline);
      expect(rules.single.height, BioStatsRow.dividerHeight);
    });
  }

  testWidgets('a framed hero keeps its edge and its rule', (tester) async {
    await tester.pumpWidget(
      _host(
        const BioHero(
          eyebrow: 'VO₂max',
          value: '41',
          stats: <BioStat>[BioStat('Trend', '+1.0')],
        ),
        AppTheme.light,
      ),
    );
    final shape = _shapeOf(tester, find.byType(BioHero)) as OutlinedBorder;
    expect(shape.side.width, hairline);
    final rule = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.child is ColoredBox);
    expect(rule.single.height, hairline);
    expect(rule.single.width, isNull, reason: 'the rule spans the card');
  });

  testWidgets('fitness wears the runner, sleep the moon, each in its hue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TodayBioHero(age: _age(), reveals: RevealRegistry()),
        AppTheme.light,
      ),
    );
    final hues = AppTheme.light.extension<InstrumentHues>()!;
    final runner = tester.widget<Icon>(find.byIcon(SolarIconsOutline.running));
    final moon = tester.widget<Icon>(find.byIcon(SolarIconsOutline.moon));
    expect(runner.color, hues.fitness);
    expect(moon.color, hues.sleep);
    expect(find.text('Fitness contribution'), findsOneWidget);
    expect(find.text('Sleep duration contribution'), findsOneWidget);
    expect(find.text('+1.1 years'), findsNWidgets(2));
  });

  testWidgets('a term the app has no family for is drawn without a badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TodayBioHero(
          age: _age(terms: const <String>['fitness', 'blood_pressure']),
          reveals: RevealRegistry(),
        ),
        AppTheme.light,
      ),
    );
    expect(find.byIcon(SolarIconsOutline.running), findsOneWidget);
    expect(find.byIcon(SolarIconsOutline.moon), findsNothing);
    expect(find.text('Blood pressure contribution'), findsOneWidget);
  });

  testWidgets('a wrapped label does not move its figure off its neighbour\'s', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TodayBioHero(age: _age(), reveals: RevealRegistry()),
        AppTheme.light,
      ),
    );
    final figures = find.text('+1.1 years');
    final tops = <double>[
      for (final element in figures.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ];
    expect(tops, hasLength(2));
    expect(tops.first, moreOrLessEquals(tops.last));
  });
}
