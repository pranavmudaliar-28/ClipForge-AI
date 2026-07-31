import 'package:flutter/material.dart';

import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/project.dart';

/// Rich project row: gradient thumb with duration overlay, title, status +
/// AI badge, last-edited, and an optional ⋯ menu.
class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap, this.onMenu});

  final Project project;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasAi = project.transcript?.segments.isNotEmpty ?? false;
    final (label, color) = switch (project.status) {
      ProjectStatus.draft => ('Draft', c.textTertiary),
      ProjectStatus.processing => ('Processing', c.warning),
      ProjectStatus.ready => ('Ready', c.accent),
      ProjectStatus.exported => ('Exported', c.success),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          _Thumb(project: project),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                Gap.h8,
                Row(children: [
                  StatusPill(label: label, color: color),
                  if (hasAi) ...[
                    Gap.w8,
                    StatusPill(label: 'AI', color: c.primary, icon: Icons.auto_awesome),
                  ],
                ]),
                Gap.h8,
                Text('Edited ${Formatters.timeAgo(project.updatedAt)}',
                    style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary),
            )
          else
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: c.brandGradient,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(Formatters.duration(project.durationMs),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
