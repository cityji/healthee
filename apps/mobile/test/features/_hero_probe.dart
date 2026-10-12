/// The pump the two biological-age hero suites share.
///
/// Split out of `today_hero_geometry_test.dart` at the 400-line gate
/// (Standards section 1): one suite asks what the card's height is made of, the
/// other asks what the field behind it does. Both need the same three things,
/// and each one is a decision rather than a convenience.
///
/// ## The real font, because the default one is a square
///
/// `flutter test` renders every glyph in a placeholder font whose characters are
/// all one em wide. In it `34.3` is 336 px wide at 84 px and clips to the whole
/// display square, so any claim about what the field does or does not cross
/// would be a claim about the wrong box. Inter is bundled with the app, so
/// [loadFigtree] measures the figure the owner actually sees.
///
/// ## Four phone widths, and not one of them is 800
///
/// `flutter test` defaults to an 800 x 600 viewport, which is wider than any
/// phone and hides every width-dependent overflow. This project has already
/// shipped a card that overflowed by 110 px behind exactly that default, so
/// every case pumps a real phone width.
///
/// Not a `*_test.dart` file, so it is never run as a suite.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/shared/v02/instruments/bio_halo.dart';

/// The widths a phone actually is. See the library docstring.
const List<double> kPhoneWidths = <double>[320, 360, 390, 414];

/// The field's own `CustomPaint`, at the size that box was laid out to.
Finder get heroField => find
    .descendant(of: find.byType(BioHalo), matching: find.byType(CustomPaint))
    .first;

/// Loads the app's own typeface, so the text boxes measured here are the real
/// ones.
Future<void> loadFigtree() async {
  // ONE file: Figtree is a variable font, so there are no static weights to
  // enumerate. The measurements below are of the real face at its default
  // instance, which is what a test can load.
  final loader = FontLoader('Figtree');
  final bytes = File('assets/fonts/Figtree.ttf').readAsBytesSync();
  loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// The halo on its own, at a phone's [width] and the old hero's height.
///
/// Today no longer draws the halo (the hero is the orb, `age_orb.dart`), so
/// the halo is measured where it is still a widget: alone, in a box the size
/// of the card it was drawn in. [store] is kept so callers did not change.
Future<void> pumpHeroAt(
  WidgetTester tester,
  LocalStore store,
  double width, {
  bool reducedMotion = true,
  ThemeData? theme,
}) async {
  tester.view
    ..physicalSize = Size(width, 3000)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 3000),
          disableAnimations: reducedMotion,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: kHaloProbeHeight,
            child: const BioHalo(),
          ),
        ),
      ),
    ),
  );
  if (reducedMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// The old hero's height at a phone width, near enough for the halo's scale.
const double kHaloProbeHeight = 520;
