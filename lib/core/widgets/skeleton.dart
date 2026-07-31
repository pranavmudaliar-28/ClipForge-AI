import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/app_dimens.dart';
import '../design/app_theme.dart';

/// Shimmering placeholder block for loading states.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = Radii.sm,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Shimmer.fromColors(
      baseColor: c.shimmerBase,
      highlightColor: c.shimmerHighlight,
      period: const Duration(milliseconds: 1400),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: c.shimmerBase, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
