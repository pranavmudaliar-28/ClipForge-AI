import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_elevation.dart';
import '../../core/design/app_motion.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.slow)..forward();

  @override
  void initState() {
    super.initState();
    _routeNext();
  }

  Future<void> _routeNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    final onboarded = ref.read(onboardingProvider);
    final user = ref.read(authProvider);
    context.go(!onboarded
        ? AppRoutes.onboarding
        : user == null
            ? AppRoutes.auth
            : AppRoutes.home);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Motion.spring),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: c.brandGradient,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  boxShadow: Shadows.glow(c.primary),
                ),
                child: const Icon(Icons.movie_creation_rounded, color: Colors.white, size: 46),
              ),
            ),
            Gap.h24,
            FadeTransition(
              opacity: _c,
              child: Text('ClipForge AI', style: context.text.headlineMedium),
            ),
            Gap.h8,
            FadeTransition(
              opacity: _c,
              child: Text('AI-first video editing',
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
