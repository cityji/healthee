/// A look-at-it harness: renders the product screens to PNG, both themes.
///
/// **Not a test.** It asserts nothing and it is deliberately named without the
/// `_test` suffix so `flutter test` never picks it up. It is run by hand:
///
/// ```bash
/// flutter test test/render/render_screens.dart
/// ls build/renders/
/// ```
///
/// ## Why it exists
///
/// `feedback_look_at_the_design` in the owner's notes is blunt about it: grep
/// output is not a design, and an agent's *report* of visual work is not the
/// work. A screen has to be rendered and looked at, before and after, or a
/// layout that overflows on a phone ships green.
///
/// ## What is real in the output and what is not
///
/// The **fonts are the app's own** — [_loadBundledFonts] registers each family
/// under the name `pubspec.yaml` gives it (`Figtree`, and `HealtheeSymbols` for
/// the bundled glyph fallback), so glyph widths, overflow and the tabular-figure
/// alignment are all genuine. It used to derive the family from the file name,
/// which registered `Figtree.ttf` as `Figtree.ttf` and drew every glyph as a
/// block. Colour, spacing and chart geometry are real either way.
///
/// The night on the Sleep screen is [kRenderNight], the same invented sample
/// night as the HTML preview (`design/mobile-preview/proposal.js`): the
/// contract snapshot's night has three stages, too few to judge a night chart.
///
/// Animations are pumped for fixed durations, never settled: the Sleep screen
/// has a ticker that never idles, and `pumpAndSettle` waited on it for nine
/// minutes.
///
/// The viewport is deliberately **taller than a phone** ([_renderSize]) so a
/// `ListView.builder` lays its whole list out in one pass and the PNG is the
/// entire scroll rather than the first screenful. The width is a real phone's.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthee/core/theme/app_theme.dart';
import 'package:healthee/data/history/history_repository.dart';
import 'package:healthee/data/store/local_store.dart';
import 'package:healthee/data/store/store_provider.dart';
import 'package:healthee/features/actions/actions_screen.dart';
import 'package:healthee/features/activity/activity_screen.dart';
import 'package:healthee/features/diagnostics/diagnostics_screen.dart';
import 'package:healthee/features/insights/insights_screen.dart';
import 'package:healthee/features/sleep/sleep_screen.dart';
import 'package:healthee/features/trends/trends_period.dart';
import 'package:healthee/features/trends/trends_screen.dart';

import '../_bio_age_stubs.dart';
import '../_sleep_stubs.dart';
import '../_today_stubs.dart';
import '../features/_today_host.dart';
import 'render_samples.dart';

/// A phone's width, and enough height that nothing is left unbuilt.
const Size _renderSize = Size(390, 3400);
const Size _tallSize = Size(390, 9000);

/// Where the PNGs land. Ignored by git — this is a look, not an artefact.
const String _outputDirectory = 'build/renders';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The owner looks at these; the debug ribbon is not part of the app.
  WidgetsApp.debugAllowBannerOverride = false;

  setUpAll(_loadBundledFonts);

  late LocalStore store;

  setUp(() async {
    store = LocalStore.memory();
    await seedDevice(store);
  });

  tearDown(() => store.close());

  for (final theme in <String, ThemeData>{
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  }.entries) {
    testWidgets('render today — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'today-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          history: sampleHistory(),
          sleep: sleepWithSampleNight(),
        ),
      );
    });

    // The paused age: the committed withheld shape with a weight 41 days old,
    // so the hero draws the headline, the server's sentence, the caption and
    // the button, and no number.
    testWidgets('render today paused — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'today-paused-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          server: todayView(
            mutate: pausedToday(absentTerms: [staleWeightTerm()]),
          ),
          profile: profileFixture(
            mutate: (json) => <String, Object?>{...json, 'weight_age_days': 41},
          ),
          history: sampleHistory(),
          sleep: sleepWithSampleNight(),
        ),
      );
    });

    testWidgets('render sleep — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'sleep-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          // Pinned, so the night labels and the whole page eyebrow are the same
          // in every render rather than drifting with the wall clock.
          home: SleepScreen(now: kSleepNow),
          sleep: sleepWithSampleNight(),
        ),
        size: _tallSize,
      );
    });

    testWidgets('render trends — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'trends-${theme.key}',
        ProviderScope(
          overrides: [
            todayProvider.overrideWithValue('2026-07-31'),
            for (final spec in kTrendSpecs)
              for (final period in TrendPeriod.values)
                metricHistoryProvider(
                  spec.metric,
                  period.fetchDays,
                ).overrideWith((ref) async => sampleSeries(spec.metric.id)),
          ],
          child: MaterialApp(theme: theme.value, home: const TrendsScreen()),
        ),
        size: const Size(390, 4200),
      );
    });

    testWidgets('render activity — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'activity-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          home: const ActivityScreen(),
        ),
      );
    });

    testWidgets('render insights — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'insights-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          home: const InsightsScreen(),
        ),
      );
    });

    testWidgets('render actions — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'actions-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          home: const ActionsScreen(),
        ),
      );
    });

    testWidgets('render diagnostics — ${theme.key}', (tester) async {
      await _shoot(
        tester,
        'diagnostics-${theme.key}',
        todayHost(
          store,
          themeOverride: theme.value,
          home: DiagnosticsScreen(now: now),
        ),
      );
    });
  }
}

/// Pumps [app] at [_renderSize] and writes `<name>.png`.
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget app, {
  Size size = _renderSize,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(RepaintBoundary(key: _boundary, child: app));
  // Charts animate on a real ticker. Pump past every reveal for a fixed time
  // rather than settle: one screen's ticker never idles.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  // Real work, so it runs on the real clock: inside the test's fake async
  // zone `toImage` never completes and the render hangs until the timeout.
  final ByteData? png = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  if (png == null) {
    fail('the render produced no bytes for $name');
  }
  final Directory directory = Directory(_outputDirectory);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  File('$_outputDirectory/$name.png').writeAsBytesSync(
    png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
  );
}

const Key _boundary = Key('render-boundary');

/// Registers the app's fonts with the test engine, under the names the app
/// asks for, so widths are the real ones and icons are icons: the two bundled
/// families `pubspec.yaml` declares, the `solar_icons` package's three (a
/// package font is asked for as `packages/<name>/<family>`), and Material's.
Future<void> _loadBundledFonts() async {
  final String solar = _packageRoot('solar_icons');
  final String flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  for (final MapEntry<String, String> face in <String, String>{
    'Figtree': 'assets/fonts/Figtree.ttf',
    'HealtheeSymbols': 'assets/fonts/InterFallback.ttf',
    for (final String style in <String>['Bold', 'Broken', 'Outline'])
      'packages/solar_icons/SolarIcons$style':
          '$solar/fonts/SolarIcons$style.ttf',
    'MaterialIcons':
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  }.entries) {
    final File file = File(face.value);
    if (!file.existsSync()) {
      fail(
        '${face.value} is missing — the render would measure a fallback face',
      );
    }
    final FontLoader loader = FontLoader(face.key)
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    await loader.load();
  }
}

/// Where pub put [package], read from the resolved package config.
String _packageRoot(String package) {
  final Map<String, Object?> config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  for (final Object? entry in config['packages']! as List<Object?>) {
    final Map<String, Object?> row = entry! as Map<String, Object?>;
    if (row['name'] == package) {
      return Uri.parse(row['rootUri']! as String).toFilePath();
    }
  }
  fail(
    '$package is not in .dart_tool/package_config.json; run flutter pub get',
  );
}
