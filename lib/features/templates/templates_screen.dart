import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/status_pill.dart';

class _Template {
  const _Template(this.name, this.category, this.icon, this.colors, this.durationSec, this.popularity);
  final String name;
  final String category;
  final IconData icon;
  final List<Color> colors;
  final int durationSec;
  final int popularity; // 0-100
}

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  int _cat = 0;
  static const _categories = [
    'Trending', 'Viral', 'YouTube Shorts', 'Instagram Reels', 'TikTok', 'Podcast',
    'Travel', 'Food', 'Gaming', 'Fitness', 'Business', 'Real Estate', 'Fashion',
    'Education', 'Cinematic',
  ];

  static const _templates = <_Template>[
    _Template('Viral Hook', 'Viral', Icons.bolt_rounded, [Color(0xFF7C5CFF), Color(0xFF22D3EE)], 15, 98),
    _Template('Bold Captions', 'YouTube Shorts', Icons.subtitles_rounded, [Color(0xFF22D3EE), Color(0xFF3B82F6)], 30, 95),
    _Template('Podcast Clip', 'Podcast', Icons.mic_rounded, [Color(0xFFFF6B6B), Color(0xFF7C5CFF)], 45, 90),
    _Template('Beat Drop', 'TikTok', Icons.music_note_rounded, [Color(0xFF30D158), Color(0xFF16A34A)], 20, 93),
    _Template('Travel Diary', 'Travel', Icons.travel_explore_rounded, [Color(0xFF0EA5C9), Color(0xFF30D158)], 40, 84),
    _Template('Food Reel', 'Food', Icons.restaurant_rounded, [Color(0xFFFFB020), Color(0xFFFF6B6B)], 25, 88),
    _Template('Gaming Montage', 'Gaming', Icons.sports_esports_rounded, [Color(0xFF7C5CFF), Color(0xFFEC4899)], 35, 91),
    _Template('Fitness Reel', 'Fitness', Icons.fitness_center_rounded, [Color(0xFFFF6B6B), Color(0xFFFFB020)], 30, 82),
    _Template('Product Promo', 'Business', Icons.storefront_rounded, [Color(0xFF3B82F6), Color(0xFF7C5CFF)], 30, 80),
    _Template('Property Tour', 'Real Estate', Icons.home_work_rounded, [Color(0xFF64748B), Color(0xFF0EA5C9)], 50, 76),
    _Template('Lookbook', 'Fashion', Icons.checkroom_rounded, [Color(0xFFEC4899), Color(0xFFFFB020)], 25, 85),
    _Template('Explainer', 'Education', Icons.school_rounded, [Color(0xFFFFB020), Color(0xFFFF6B6B)], 60, 79),
    _Template('Cinematic Intro', 'Cinematic', Icons.movie_filter_rounded, [Color(0xFF0F172A), Color(0xFF7C5CFF)], 12, 94),
  ];

  List<_Template> get _filtered {
    final cat = _categories[_cat];
    if (cat == 'Trending') return [..._templates]..sort((a, b) => b.popularity.compareTo(a.popularity));
    return _templates.where((t) => t.category == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.screen, Gap.md, Gap.screen, 0),
              child: Text('Templates', style: context.text.headlineMedium),
            ),
            Gap.h12,
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.screen),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => Gap.w8,
                itemBuilder: (_, i) => AppChip(
                  label: _categories[i],
                  selected: _cat == i,
                  onTap: () => setState(() => _cat = i),
                ),
              ),
            ),
            Gap.h16,
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('More ${_categories[_cat]} templates coming soon',
                          style: context.text.bodyMedium?.copyWith(color: context.colors.textTertiary)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(Gap.screen, 0, Gap.screen, Gap.huge),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: Gap.md,
                        crossAxisSpacing: Gap.md,
                        childAspectRatio: 0.74,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _TemplateCard(
                        t: list[i],
                        onApply: () => context.push(AppRoutes.upload),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.t, required this.onApply});
  final _Template t;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onApply,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.colors),
                    ),
                    child: Icon(t.icon, color: Colors.white.withValues(alpha: 0.9), size: 40),
                  ),
                  Positioned(
                    top: Gap.sm,
                    left: Gap.sm,
                    child: StatusPill(label: 'AI', color: Colors.white, icon: Icons.auto_awesome),
                  ),
                  Positioned(
                    bottom: Gap.sm,
                    right: Gap.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${t.durationSec}s',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 13, color: c.warning),
                    const SizedBox(width: 3),
                    Text('${t.popularity}%',
                        style: context.text.labelMedium?.copyWith(color: c.textTertiary)),
                    const Spacer(),
                    Text('Apply', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
