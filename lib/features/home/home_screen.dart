import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_elevation.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/pressable.dart';
import '../../providers/auth_provider.dart';
import '../../providers/projects_provider.dart';
import '../projects/widgets/project_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final projects = ref.watch(projectsProvider);
    final recent = projects.take(4).toList();
    final continueEditing = projects.isNotEmpty ? projects.first : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.md, Gap.screen, Gap.huge),
          children: [
            _Greeting(name: user?.name ?? 'Creator'),
            Gap.h24,
            _PrimaryActions(onNew: () => context.push(AppRoutes.upload)),
            if (continueEditing != null) ...[
              Gap.h32,
              _Header(title: 'Continue editing'),
              Gap.h12,
              ProjectCard(
                project: continueEditing,
                onTap: () => context.push(AppRoutes.editorFor(continueEditing.id)),
              ),
            ],
            Gap.h32,
            _Header(title: 'Trending templates', action: 'See all', onAction: () => context.go(AppRoutes.templates)),
            Gap.h12,
            const _TrendingTemplates(),
            Gap.h32,
            _Header(
              title: 'Recent projects',
              action: recent.isEmpty ? null : 'All',
              onAction: () => context.go(AppRoutes.projects),
            ),
            Gap.h12,
            if (recent.isEmpty)
              _EmptyProjects(onNew: () => context.push(AppRoutes.upload))
            else
              ...recent.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.md),
                    child: ProjectCard(project: p, onTap: () => context.push(AppRoutes.editorFor(p.id))),
                  )),
            Gap.h24,
            const _ProBanner(),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hour = TimeOfDay.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
              Gap.h4,
              Text(name, style: context.text.headlineMedium),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: context.text.titleLarge),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            title: 'New Project',
            subtitle: 'Start from scratch',
            icon: Icons.add_rounded,
            gradient: c.brandGradient,
            glow: true,
            onTap: onNew,
          ),
        ),
        Gap.w12,
        Expanded(
          child: _ActionTile(
            title: 'AI Auto Edit',
            subtitle: 'Upload & let AI cut',
            icon: Icons.auto_awesome,
            gradient: LinearGradient(colors: [c.accent, c.primary]),
            onTap: onNew,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.glow = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 124,
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: glow ? Shadows.glow(c.primary) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTemplates extends StatelessWidget {
  const _TrendingTemplates();

  static const _items = <(String, IconData, List<Color>)>[
    ('Viral Hook', Icons.bolt_rounded, [Color(0xFF7C5CFF), Color(0xFF22D3EE)]),
    ('Podcast Clip', Icons.mic_rounded, [Color(0xFFFF6B6B), Color(0xFF7C5CFF)]),
    ('Vlog Cut', Icons.videocam_rounded, [Color(0xFF22D3EE), Color(0xFF30D158)]),
    ('Tutorial', Icons.school_rounded, [Color(0xFFFFB020), Color(0xFFFF6B6B)]),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => Gap.w12,
        itemBuilder: (_, i) {
          final (label, icon, colors) = _items[i];
          return Container(
            width: 122,
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onNew,
      child: Row(children: [
        Icon(Icons.video_library_outlined, color: c.textTertiary, size: 28),
        Gap.w12,
        Expanded(
          child: Text('No projects yet. Tap to create your first edit.',
              style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
        ),
        Icon(Icons.add_rounded, color: c.primary),
      ]),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withValues(alpha: 0.35)),
        gradient: LinearGradient(colors: [
          c.primary.withValues(alpha: 0.16),
          c.accent.withValues(alpha: 0.10),
        ]),
      ),
      child: Row(children: [
        Icon(Icons.workspace_premium_rounded, color: c.warning, size: 30),
        Gap.w12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Go Pro', style: context.text.titleMedium),
              const SizedBox(height: 2),
              Text('4K export · no watermark · unlimited AI',
                  style: context.text.labelMedium?.copyWith(color: c.textSecondary)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      ]),
    );
  }
}
