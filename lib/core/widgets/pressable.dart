import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_motion.dart';

/// Wraps a child with a subtle scale-down on press + haptic feedback — the
/// tactile foundation shared by buttons, cards, and tiles.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = HapticFeedback.selectionClick,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Future<void> Function() haptic;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _set(bool v) {
    if (_active && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: _active
          ? () {
              widget.haptic();
              widget.onTap?.call();
            }
          : null,
      onLongPress: _active && widget.onLongPress != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: Motion.fast,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}
