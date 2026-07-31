import 'package:flutter/material.dart';

import '../design/app_dimens.dart';
import '../design/app_elevation.dart';
import '../design/app_theme.dart';
import 'pressable.dart';

/// Standard surface card: themed fill, hairline border, soft elevation, and
/// press feedback when tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.radius = Radii.lg,
    this.elevated = true,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool elevated;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
        boxShadow: elevated ? Shadows.card(c.isDark) : null,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
