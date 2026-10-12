/// **v02's type scale, fourth seam: the biological-age figure.**
///
/// Split out of `type_scale.dart` at the 400-line gate (Standards section 1),
/// the same way `type_scale_forms.dart` and `type_scale_dates.dart` were. What
/// is left belongs to ONE instrument's refusal: the withheld age figure and the
/// date line under it (`bio_hero_parts.dart`). Each role is an alias of a step
/// on `type_ladder.dart`.
///
/// **Colourless**, like the rest of the scale.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/type_ladder.dart';

/// The bio figure's scale. Colourless; see the library docstring.
abstract final class BioType {
  /// `.bio-hero .age-value` — the age figure, at the ladder's display step.
  static final TextStyle bioAge = TypeLadder.display;

  /// `.bio-hero .age-context` — the sentence under the figure.
  static final TextStyle bioContext = TypeLadder.caption;
}
