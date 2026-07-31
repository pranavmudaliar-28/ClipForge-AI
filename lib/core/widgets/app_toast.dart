import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_dimens.dart';
import '../design/app_theme.dart';

enum ToastType { info, success, error }

/// Styled toast with icon + haptic. Use instead of raw SnackBars for a
/// consistent, premium feel.
void showAppToast(BuildContext context, String message, {ToastType type = ToastType.info}) {
  final c = context.colors;
  final (icon, tint) = switch (type) {
    ToastType.success => (Icons.check_circle_rounded, c.success),
    ToastType.error => (Icons.error_rounded, c.error),
    ToastType.info => (Icons.info_rounded, c.accent),
  };
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceHigh,
        margin: const EdgeInsets.all(Gap.lg),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
        content: Row(
          children: [
            Icon(icon, color: tint, size: 20),
            Gap.w12,
            Expanded(child: Text(message, style: TextStyle(color: c.textPrimary))),
          ],
        ),
      ),
    );
}
