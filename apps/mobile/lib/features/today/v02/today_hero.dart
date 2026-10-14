/// The screen's centrepiece. The three key numbers under it are
/// `today_key_numbers.dart`'s.
///
/// `panels.js::H.bioHero` in order: the eyebrow, the halo with the figure inside
/// it, the sentence about the delta, the 28–44 ruler, a full-bleed rule, the two
/// contributions, and the model label.
///
/// ## Everything here is the server's, and an absence stays an absence
///
/// The figure is `biological_age.biological_age`; the sentence is built from
/// `delta_years` and `chronological_age` and is **omitted entirely** when either
/// is null, rather than saying "0.0 years below" about an age nothing compared.
/// The two contributions are `contributions[]`, in the payload's own order, with
/// the payload's own terms — not a fixed Fitness/Sleep pair, because a model
/// that stops sending a term must stop showing it.
///
/// The model label is the server's `disclaimer` when it sent one. The fallback
/// is the prototype's own line, which is a statement about the method rather
/// than about the owner, so it is safe to print unconditionally.
library;

import 'package:flutter/material.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/shared/format/age_lever_format.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/age_orb_hero.dart';
import 'package:healthee/shared/v02/bio_stats.dart';
import 'package:healthee/shared/v02/instruments/age_slider.dart';
import 'package:healthee/shared/v02/key_number_card.dart';

/// Under the hero's title: what the number is, before anyone reads it.
const String kAgeOrbSubtitle = 'An estimate, not a clinical age';

/// What the prototype prints under the age when the server sent no disclaimer.
const String kPopulationModelLabel =
    'Population-based model · not a clinical age';

/// The biological-age hero, with the halo around the figure.
///
/// Nothing here holds state. A hand pause shipped beside the arrow for a while,
/// on the strength of the prototype's README; the owner looked at it on the
/// device and asked for it to go. The field's three automatic stops — offscreen,
/// backgrounded, reduced motion — are not a preference and are the field's own.
class TodayBioHero extends StatelessWidget {
  /// [age] is the payload's block; nothing here is computed.
  const TodayBioHero({
    required this.age,
    required this.reveals,
    this.onOpenBody,
    this.onOpenTerm,
    super.key,
  });

  /// The prototype's eyebrow for this card.
  static const String eyebrow = 'Biological age · estimate';

  /// The prototype's own `aria-label` on the eyebrow's anchor.
  static const String eyebrowSemantics = 'Understand your biological age';

  /// The estimate and everything the server said about it.
  final BiologicalAge age;

  /// Where "this instrument has already revealed" is remembered.
  final RevealRegistry reveals;

  /// `<a href="#body">` on the eyebrow's arrow — the calculation behind the
  /// figure.
  final VoidCallback? onOpenBody;

  /// Where one contribution row goes, by its `term`.
  ///
  /// `.bio-bottom` is two anchors in the prototype — `#fitness` and `#sleep` —
  /// and the term decides which. Passing the term rather than two callbacks is
  /// what keeps the hero honest about a model that adds a third one: the host
  /// answers for the term it is given, or does not, and the row is drawn either
  /// way.
  final void Function(String term)? onOpenTerm;

  @override
  Widget build(BuildContext context) {
    final chronological = age.chronologicalAge;
    return AgeOrbHero(
      value: figureOf(age.biologicalAge),
      verdict: verdictOf(age),
      subtitle: kAgeOrbSubtitle,
      modelLabel: age.disclaimer ?? kPopulationModelLabel,
      onOpen: onOpenBody,
      openSemantics: eyebrowSemantics,
      slider: chronological == null
          ? null
          : RevealOnce(
              id: 'today.bio-age-scale',
              registry: reveals,
              builder: (context, t) => AgeSlider(
                estimate: age.biologicalAge,
                actual: chronological,
                progress: t,
              ),
            ),
      stats: <BioStat>[
        for (final term in age.contributions)
          if (term.deltaYears case final double delta)
            BioStat(
              _termName(term.term),
              '${signedYears(delta)} years',
              onOpen: onOpenTerm == null ? null : () => onOpenTerm!(term.term),
            ),
      ],
    );
  }

  /// `1.7 years younger`, `2.0 years older`, or `Your actual age`; null when
  /// nothing was compared.
  static Verdict? verdictOf(BiologicalAge age) {
    final delta = age.deltaYears;
    if (delta == null || age.chronologicalAge == null) {
      return null;
    }
    final magnitude = delta.abs().toStringAsFixed(1);
    return delta == 0
        ? const Verdict('Your actual age', VerdictTone.neutral)
        : delta < 0
        ? Verdict('$magnitude years younger', VerdictTone.better)
        : Verdict('$magnitude years older', VerdictTone.worse);
  }

  /// `34.3`, and `34` when the estimate is whole. Never `34.0`.
  static String figureOf(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  /// `fitness` → `Fitness`; `sleep_regularity` → `Sleep regularity`.
  ///
  /// A model term is a word the server chose, not a metric id, so this is
  /// formatting rather than naming. Underscores go because a snake_case run on
  /// a health screen reads as a log line — the rule `note_names.dart` exists
  /// for, applied to the one other place an identifier reaches the surface.
  static String _termName(String term) {
    final words = term.replaceAll('_', ' ').trim();
    if (words.isEmpty) {
      return term;
    }
    return words[0].toUpperCase() + words.substring(1);
  }
}
