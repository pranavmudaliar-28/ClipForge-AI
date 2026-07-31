import 'package:flutter/widgets.dart';

/// Soft, layered shadow sets (replaces the old heavy purple glow). Shadows are
/// darker/softer in light mode and near-invisible in dark mode where elevation
/// is conveyed by surface tint instead.
abstract final class Shadows {
  static List<BoxShadow> card(bool isDark) => isDark
      ? const [
          BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
        ]
      : const [
          BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x14101828), blurRadius: 16, offset: Offset(0, 8)),
        ];

  static List<BoxShadow> sheet(bool isDark) => isDark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, -8))]
      : const [BoxShadow(color: Color(0x1F101828), blurRadius: 32, offset: Offset(0, -8))];

  /// Colored glow for a primary CTA (used sparingly).
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
      ];
}
