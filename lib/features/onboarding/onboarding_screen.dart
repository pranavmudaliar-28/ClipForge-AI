import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_elevation.dart';
import '../../core/design/app_motion.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../providers/onboarding_provider.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_Slide>[
    _Slide(Icons.auto_awesome, 'Edit with AI',
        'Drop in raw footage and let ClipForge find the best moments, cut the silence, and build your first edit.'),
    _Slide(Icons.subtitles_rounded, 'Captions that pop',
        'Accurate captions from real speech-to-text, styled to match your brand in a single tap.'),
    _Slide(Icons.dashboard_customize_rounded, 'A real editor',
        'Every AI decision lands on a pro multi-track timeline you can trim, split, and perfect before export.'),
  ];

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (mounted) context.go(AppRoutes.auth);
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: Motion.medium, curve: Motion.standard);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip', style: TextStyle(color: c.textSecondary)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xxxl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            gradient: c.brandGradient,
                            borderRadius: BorderRadius.circular(Radii.xl),
                            boxShadow: Shadows.glow(c.primary),
                          ),
                          child: Icon(s.icon, size: 54, color: Colors.white),
                        ),
                        Gap.h32,
                        Text(s.title, textAlign: TextAlign.center, style: context.text.headlineMedium),
                        Gap.h12,
                        Text(s.body,
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(color: c.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: Motion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? c.primary : c.surfaceHigh,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.screen),
              child: AppButton(
                label: last ? 'Get started' : 'Next',
                icon: last ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
