/// The biological-age orb: a sphere whose particles crowd its rim, with the
/// figure in its still, dark centre. Modelled on WHOOP's Healthspan orb, which
/// the owner asked for by name.
///
/// ## Why it is cheap
///
/// The halo it replaces moved 1,400 particles with trails at 30 fps and read
/// as sluggish on the owner's phone. This one is painted **once**: the
/// particles are fixed (seeded), batched by size into a handful of
/// `drawRawPoints` calls, and kept behind a `RepaintBoundary`. The only motion
/// is a slow turn of that finished layer, a compositor transform that repaints
/// nothing, and it is off under the system's reduced-motion setting.
///
/// It takes no reading. It is decoration around the figure, which is drawn by
/// the caller and never moves.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/tokens.dart';

/// One full turn of the particle layer.
const Duration kOrbTurn = Duration(seconds: 150);

/// Particles in the orb.
const int kOrbParticles = 1800;

/// The orb, [diameter] across, with [child] centred in it.
class AgeOrb extends StatefulWidget {
  const AgeOrb({
    required this.diameter,
    required this.child,
    this.turning = true,
    super.key,
  });

  final double diameter;
  final Widget child;

  /// False holds it still: an orb turning around a number that is not there
  /// would be decoration pretending to be a reading.
  final bool turning;

  @override
  State<AgeOrb> createState() => _AgeOrbState();
}

class _AgeOrbState extends State<AgeOrb> with SingleTickerProviderStateMixin {
  AnimationController? _turn;

  /// While stopped off screen, how often it looks again. A timer, not a
  /// frame: a stopped orb schedules nothing.
  Timer? _watch;
  int _ticks = 0;

  /// Looks every this many frames while turning.
  static const int checkEvery = 30;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        !widget.turning ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still) {
      _watch?.cancel();
      _turn?.dispose();
      _turn = null;
    } else {
      _turn ??= AnimationController(vsync: this, duration: kOrbTurn)
        ..addListener(() {
          if (++_ticks % checkEvery == 0) {
            _follow();
          }
        });
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  /// Turns while any of it is on screen, and stops when none of it is. The
  /// hero sits in a box the list keeps alive, so the list cannot say this.
  void _follow() {
    final turn = _turn;
    if (!mounted || turn == null) {
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return;
    }
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = MediaQuery.sizeOf(context).height;
    final seen = top < screen && top + box.size.height > 0;
    if (seen && !turn.isAnimating) {
      _watch?.cancel();
      unawaited(turn.repeat());
    } else if (!seen && turn.isAnimating) {
      turn.stop();
      _watch = Timer.periodic(const Duration(seconds: 1), (_) => _follow());
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _turn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = colors.bg.computeLuminance() < 0.2;
    final painted = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.diameter),
        painter: OrbPainter(
          rim: context.hues.fitness,
          ground: colors.bg,
          spark: colors.bioInk,
          dark: dark,
        ),
      ),
    );
    final turn = _turn;
    return SizedBox.square(
      dimension: widget.diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: turn == null
                ? painted
                : RotationTransition(turns: turn, child: painted),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Paints the orb. Everything it draws is fixed, so it repaints only when the
/// theme changes.
class OrbPainter extends CustomPainter {
  OrbPainter({
    required this.rim,
    required this.ground,
    required this.spark,
    required this.dark,
  });

  /// The family green the rim and particles are drawn in.
  final Color rim;

  /// The page, which the centre fades into.
  final Color ground;

  /// The few brightest particles.
  final Color spark;

  final bool dark;

  /// Unit-circle positions, sizes and brightness, made once for every orb.
  static final List<({double x, double y, double size, double glow})> _dots =
      _seed();

  static List<({double x, double y, double size, double glow})> _seed() {
    final random = math.Random(29);
    return <({double x, double y, double size, double glow})>[
      for (var i = 0; i < kOrbParticles; i++)
        () {
          // Most particles sit near the rim; a thin scatter reaches inward.
          final depth = math.pow(random.nextDouble(), 2.8).toDouble();
          final r = 1 - 0.58 * depth;
          final a = random.nextDouble() * 2 * math.pi;
          final s = random.nextDouble();
          return (
            x: r * math.cos(a),
            y: r * math.sin(a),
            size: 0.7 + 3.0 * s * s * s,
            glow: (1 - depth) * (0.35 + 0.65 * random.nextDouble()),
          );
        }(),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final body = radius * 0.92;
    // Outer glow, then the body: dark centre, green towards the rim.
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          radius,
          <Color>[
            rim.withValues(alpha: dark ? 0.22 : 0.14),
            rim.withValues(alpha: 0),
          ],
          <double>[body / radius, 1],
        ),
    );
    canvas.drawCircle(
      c,
      body,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          body,
          <Color>[
            ground,
            ground,
            rim.withValues(alpha: dark ? 0.05 : 0.04),
            rim.withValues(alpha: dark ? 0.18 : 0.12),
          ],
          <double>[0, 0.6, 0.88, 1],
        ),
    );
    // Particles, batched by size and brightness, scaled to the orb: a dot is
    // the same share of the sphere on every phone.
    final scale = body / 120;
    for (final size in <double>[1.1, 1.9, 2.7, 3.5]) {
      for (final level in <double>[0.3, 0.6, 0.9]) {
        final points = <double>[
          for (final d in _dots)
            if ((d.size - size).abs() <= 0.4 &&
                (d.glow - level).abs() <= 0.15) ...<double>[
              c.dx + d.x * body,
              c.dy + d.y * body,
            ],
        ];
        if (points.isEmpty) {
          continue;
        }
        final raw = Float32List.fromList(points);
        // The biggest, brightest dots bloom: a wide faint pass under them.
        if (size > 2.5 && level > 0.5) {
          canvas.drawRawPoints(
            ui.PointMode.points,
            raw,
            Paint()
              ..color = rim.withValues(alpha: dark ? 0.07 : 0.05)
              ..strokeWidth = size * scale * 3
              ..strokeCap = StrokeCap.round,
          );
        }
        final ink = size > 3 && level > 0.8 && dark ? spark : rim;
        canvas.drawRawPoints(
          ui.PointMode.points,
          raw,
          Paint()
            ..color = ink.withValues(alpha: (dark ? 1.0 : 0.9) * level)
            ..strokeWidth = size * scale
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    // The crisp edge, with a soft glow under it.
    canvas
      ..drawCircle(
        c,
        body,
        Paint()
          ..color = rim.withValues(alpha: dark ? 0.25 : 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawCircle(
        c,
        body,
        Paint()
          ..color = rim.withValues(alpha: dark ? 0.55 : 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.rim != rim ||
      old.ground != ground ||
      old.spark != spark ||
      old.dark != dark;
}
