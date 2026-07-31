import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/projects_provider.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(authProvider);
    final count = ref.watch(projectsProvider).length;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.screen),
          children: [
            Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(Radii.lg)),
                alignment: Alignment.center,
                child: Text((user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26)),
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? 'Creator', style: context.text.titleLarge),
                    Text(user?.email ?? '', style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ]),
            Gap.h24,
            Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                Gap.w12,
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Upgrade to Pro',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 2),
                    Text('4K · no watermark · unlimited AI', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ]),
            ),
            Gap.h20,
            Row(children: [
              _Stat(value: '$count', label: 'Projects'),
              Gap.w12,
              const _Stat(value: '50', label: 'AI credits'),
              Gap.w12,
              const _Stat(value: '720p', label: 'Max export'),
            ]),
            Gap.h24,
            Text('Appearance', style: context.text.titleMedium),
            Gap.h12,
            Row(children: [
              _ThemeChip(label: 'System', selected: mode == ThemeMode.system, onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.system)),
              Gap.w8,
              _ThemeChip(label: 'Light', selected: mode == ThemeMode.light, onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light)),
              Gap.w8,
              _ThemeChip(label: 'Dark', selected: mode == ThemeMode.dark, onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark)),
            ]),
            Gap.h24,
            Text('More', style: context.text.titleMedium),
            Gap.h12,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _link(context, Icons.help_outline_rounded, 'Help & support'),
                Divider(height: 1, color: c.border),
                _link(context, Icons.privacy_tip_outlined, 'Privacy policy'),
                Divider(height: 1, color: c.border),
                _link(context, Icons.info_outline_rounded, 'About ClipForge AI'),
              ]),
            ),
            Gap.h20,
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).signOut();
                if (context.mounted) context.go(AppRoutes.auth);
              },
              icon: Icon(Icons.logout_rounded, color: c.error),
              label: Text('Log out', style: TextStyle(color: c.error)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(color: c.error.withValues(alpha: 0.4)),
                shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
              ),
            ),
            Gap.h16,
            Center(child: Text('ClipForge AI · v0.2.0', style: context.text.labelMedium?.copyWith(color: c.textTertiary))),
          ],
        ),
      ),
    );
  }

  Widget _link(BuildContext context, IconData icon, String label) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon, color: c.textSecondary),
      title: Text(label),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textTertiary),
      onTap: () {},
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      Expanded(child: Center(child: AppChip(label: label, selected: selected, onTap: onTap)));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(children: [
          Text(value, style: context.text.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
        ]),
      ),
    );
  }
}
