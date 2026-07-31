import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale — Inter for UI text, JetBrains Mono for technical readouts
/// (timecodes, resolutions). Mapped onto Material [TextTheme] slots so widgets
/// get theme-aware colors for free.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base, Color primary, Color secondary) {
    final t = GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: _s(34, FontWeight.w800, -0.5, 1.1),
      displayMedium: _s(28, FontWeight.w800, -0.4, 1.15),
      displaySmall: _s(24, FontWeight.w700, -0.3, 1.2),
      headlineMedium: _s(22, FontWeight.w700, -0.3, 1.2),
      headlineSmall: _s(20, FontWeight.w700, -0.2, 1.25),
      titleLarge: _s(18, FontWeight.w700, -0.1, 1.3),
      titleMedium: _s(16, FontWeight.w600, 0, 1.3),
      titleSmall: _s(14, FontWeight.w600, 0, 1.35),
      bodyLarge: _s(16, FontWeight.w400, 0, 1.5),
      bodyMedium: _s(14, FontWeight.w400, 0, 1.45),
      bodySmall: _s(13, FontWeight.w400, 0.1, 1.4),
      labelLarge: _s(14, FontWeight.w600, 0.1, 1.2),
      labelMedium: _s(12, FontWeight.w600, 0.2, 1.2),
      labelSmall: _s(11, FontWeight.w600, 0.3, 1.2),
    );
    return t.apply(bodyColor: primary, displayColor: primary).copyWith(
          bodyMedium: t.bodyMedium?.copyWith(color: secondary),
          bodySmall: t.bodySmall?.copyWith(color: secondary),
          labelMedium: t.labelMedium?.copyWith(color: secondary),
          labelSmall: t.labelSmall?.copyWith(color: secondary),
        );
  }

  static TextStyle _s(double size, FontWeight w, double tracking, double height) =>
      TextStyle(fontSize: size, fontWeight: w, letterSpacing: tracking, height: height);

  /// Monospace style for timecodes / technical labels.
  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
