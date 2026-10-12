/// Today's age hero on the page itself, WHOOP style: no card, no edge, and the
/// model's terms as two coloured figures.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/features/today/v02/today_hero.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/age_orb_hero.dart';

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

void main() {
  for (final MapEntry<String, ThemeData> theme in <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('Today\'s hero has no card, edge or ground — ${theme.key}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          TodayBioHero(age: _age(), reveals: RevealRegistry()),
          theme.value,
        ),
      );
      final hero = find.byType(AgeOrbHero);
      expect(hero, findsOneWidget);
      final colors = theme.value.extension<HealtheeColors>()!;
      Color? fill(Decoration? d) => switch (d) {
        final BoxDecoration box => box.color,
        final ShapeDecoration shape => shape.color,
        _ => null,
      };
      // No box under the hero is painted in a card's ground.
      final grounds = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: hero, matching: find.byType(DecoratedBox)),
          )
          .where((box) => fill(box.decoration) == colors.surface);
      expect(grounds, isEmpty, reason: 'the page is the ground');
    });
  }

  testWidgets('each term is named, and older is the amber side', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TodayBioHero(age: _age(), reveals: RevealRegistry()),
        AppTheme.light,
      ),
    );
    expect(find.text('FITNESS'), findsOneWidget);
    expect(find.text('SLEEP DURATION'), findsOneWidget);
    final older = tester.widgetList<Text>(find.text('+1.1 years'));
    expect(older, hasLength(2));
    for (final figure in older) {
      expect(
        figure.style!.color,
        AppTheme.light.extension<HealtheeColors>()!.unf,
      );
    }
  });

  testWidgets('a term the app has no family for is named all the same', (
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
    expect(find.text('FITNESS'), findsOneWidget);
    expect(find.text('BLOOD PRESSURE'), findsOneWidget);
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
