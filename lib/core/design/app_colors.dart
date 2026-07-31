import 'package:flutter/material.dart';

/// Semantic color roles for ClipForge AI, available for **light and dark**.
///
/// Registered as a [ThemeExtension] so colors animate on theme switch and are
/// read via `context.colors`. The palette is neutral-forward (Linear/Arc-style
/// layered surfaces) with the brand violet used as a restrained accent — not the
/// old "gradient everywhere" look.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.scrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Brightness brightness;
  final Color bg; // app background
  final Color surface; // cards, sheets
  final Color surfaceElevated; // raised panels
  final Color surfaceHigh; // inputs, chips
  final Color border; // hairline
  final Color borderStrong; // emphasised hairline
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary; // brand accent (violet)
  final Color primaryPressed;
  final Color onPrimary;
  final Color accent; // secondary highlight (blue)
  final Color success;
  final Color warning;
  final Color error;
  final Color scrim; // modal barrier
  final Color shimmerBase;
  final Color shimmerHighlight;

  bool get isDark => brightness == Brightness.dark;

  /// Brand gradient — reserved for hero CTAs only, used sparingly.
  Gradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, accent],
      );

  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF0A0A0C),
    surface: Color(0xFF141418),
    surfaceElevated: Color(0xFF1B1B21),
    surfaceHigh: Color(0xFF26262E),
    border: Color(0x14FFFFFF), // white 8%
    borderStrong: Color(0x24FFFFFF), // white 14%
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA6A6B2),
    textTertiary: Color(0xFF6C6C78),
    primary: Color(0xFF7C5CFF),
    primaryPressed: Color(0xFF6A4AEF),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF22D3EE),
    success: Color(0xFF30D158),
    warning: Color(0xFFFFD60A),
    error: Color(0xFFFF453A),
    scrim: Color(0x99000000),
    shimmerBase: Color(0xFF1B1B21),
    shimmerHighlight: Color(0xFF26262E),
  );

  static const light = AppColors(
    brightness: Brightness.light,
    bg: Color(0xFFF6F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFEFF3),
    border: Color(0x14000000), // black 8%
    borderStrong: Color(0x22000000), // black 13%
    textPrimary: Color(0xFF0E0E12),
    textSecondary: Color(0xFF56565F),
    textTertiary: Color(0xFF8A8A94),
    primary: Color(0xFF6A4AEF),
    primaryPressed: Color(0xFF5A3CDF),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF0EA5C9),
    success: Color(0xFF1FA855),
    warning: Color(0xFFC98A00),
    error: Color(0xFFE5352B),
    scrim: Color(0x66000000),
    shimmerBase: Color(0xFFECECEF),
    shimmerHighlight: Color(0xFFF7F7FA),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceHigh,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? scrim,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      scrim: scrim ?? this.scrim,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceElevated: c(surfaceElevated, other.surfaceElevated),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      primary: c(primary, other.primary),
      primaryPressed: c(primaryPressed, other.primaryPressed),
      onPrimary: c(onPrimary, other.onPrimary),
      accent: c(accent, other.accent),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      scrim: c(scrim, other.scrim),
      shimmerBase: c(shimmerBase, other.shimmerBase),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
    );
  }
}
