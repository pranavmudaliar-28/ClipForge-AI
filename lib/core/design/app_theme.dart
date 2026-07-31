import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Builds light + dark [ThemeData] from the [AppColors] token set.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      onSecondary: c.isDark ? Colors.black : Colors.white,
      error: c.error,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
    );

    final base = ThemeData(brightness: c.brightness, useMaterial3: true);
    final textTheme = AppTypography.textTheme(base.textTheme, c.textPrimary, c.textSecondary);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      extensions: [c],
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rLg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        hintStyle: TextStyle(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        border: const OutlineInputBorder(borderRadius: Radii.rMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.rMd, borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.rMd, borderSide: BorderSide(color: c.primary, width: 1.5)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        contentTextStyle: TextStyle(color: c.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceHigh,
        thumbColor: Colors.white,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}

/// `context.colors` — theme-aware semantic palette.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  TextTheme get text => Theme.of(this).textTheme;
}
