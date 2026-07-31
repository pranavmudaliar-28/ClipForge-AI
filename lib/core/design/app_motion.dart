import 'package:flutter/animation.dart';

/// Motion tokens — consistent durations + curves for a cohesive feel.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 360);

  /// Standard easing (Material emphasized-ish).
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Springy pop for success / selection.
  static const Curve spring = Curves.easeOutBack;
}
