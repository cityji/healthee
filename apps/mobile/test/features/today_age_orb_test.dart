/// Today's biological-age hero, the WHOOP-style orb: it fits every phone, the
/// figure sits inside the orb, and its controls and terms are its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/metric_info/metric_info_sheet.dart';
import 'package:healthee/shared/v02/age_orb_hero.dart';
import 'package:healthee/shared/v02/instruments/age_slider.dart';
import 'package:healthee/shared/v02/instruments/age_sphere.dart';
import 'package:healthee/shared/v02/instruments/age_sphere_painter.dart';

import '_hero_probe.dart';
import '_today_host.dart';

void main() {
  setUpAll(loadFigtree);
  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });
  tearDown(() async => store.close());

  for (final width in kPhoneWidths) {
    testWidgets('$width — the orb fits, and everything is inside the hero', (
      tester,
    ) async {
      tester.view
        ..physicalSize = Size(width, 3000)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayHost(store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at $width');

      final hero = tester.getRect(find.byType(AgeOrbHero));
      final orb = tester.getRect(find.byType(AgeSphere));
      final inner = hero.width - 2 * AgeOrbHero.side;
      expect(orb.width, closeTo(math.min(inner, AgeOrbHero.orbMax), 0.5));
      expect(orb.center.dx, closeTo(hero.center.dx, 0.5), reason: 'centred');
      expect(orb.contains(tester.getRect(find.text('34.3')).center), isTrue);
      for (final part in <Finder>[
        find.descendant(
          of: find.byType(AgeOrbHero),
          matching: find.byType(MetricInfoDot),
        ),
        find.byKey(AgeSlider.plotKey),
        find.text('FITNESS'),
      ]) {
        final rect = tester.getRect(part);
        expect(hero.contains(rect.topLeft), isTrue, reason: '$part');
        expect(hero.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
      }
    });
  }

  testWidgets('the orb paints, and it paints no reading', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 3000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(todayHost(store));
    await tester.pumpAndSettle();
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(AgeSphere),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((paint) => paint.painter)
        .whereType<AgeSpherePainter>()
        .single;
    // Decoration only: the painter is built from colours, never a value.
    expect(painter.shouldRepaint(painter), isFalse);
  });
}
