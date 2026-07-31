import 'package:flutter/material.dart';

import '../design/app_dimens.dart';
import '../design/app_elevation.dart';
import '../design/app_theme.dart';
import 'pressable.dart';

enum AppButtonVariant { primary, tonal, ghost, destructive }

enum AppButtonSize { large, medium, small }

/// The single button component for the app. Variants + sizes, press-scale +
/// haptics (via [Pressable]), loading + icon support, full a11y sizing.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.tonal({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.large,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.tonal;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool expand;

  double get _height => switch (size) {
        AppButtonSize.large => 54,
        AppButtonSize.medium => 46,
        AppButtonSize.small => 38,
      };

  double get _fontSize => switch (size) {
        AppButtonSize.large => 16,
        AppButtonSize.medium => 15,
        AppButtonSize.small => 13,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color fg;
    Border? border;
    List<BoxShadow>? shadow;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = c.primary;
        fg = c.onPrimary;
        shadow = enabled ? Shadows.glow(c.primary) : null;
      case AppButtonVariant.tonal:
        bg = c.surfaceHigh;
        fg = c.textPrimary;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = c.textPrimary;
        border = Border.all(color: c.borderStrong);
      case AppButtonVariant.destructive:
        bg = c.error.withValues(alpha: 0.14);
        fg = c.error;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _height,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? Gap.md : Gap.xl),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(size == AppButtonSize.small ? Radii.sm : Radii.md),
            border: border,
            boxShadow: shadow,
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(fg)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: _fontSize + 4, color: fg),
                        Gap.w8,
                      ],
                      Text(
                        label,
                        style: TextStyle(color: fg, fontSize: _fontSize, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
