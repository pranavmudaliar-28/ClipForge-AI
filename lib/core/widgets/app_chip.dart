import 'package:flutter/material.dart';

import '../design/app_dimens.dart';
import '../design/app_motion.dart';
import '../design/app_theme.dart';
import 'pressable.dart';

/// Selectable pill chip — used for category filters and segmented choices.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.primary : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? c.onPrimary : c.textSecondary),
              Gap.w4,
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? c.onPrimary : c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
