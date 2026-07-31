import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/ai_processing/ai_processing_screen.dart';
import '../../features/ai_wizard/ai_wizard_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/editor/editor_screen.dart';
import '../../features/export/export_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/templates/templates_screen.dart';
import '../../features/upload/upload_screen.dart';
import 'app_routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Navigation is imperative: the splash screen decides where to go based on
/// onboarding/auth state, and each flow pushes the next. No global redirect.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
    GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.auth, builder: (_, _) => const AuthScreen()),

    // Full-screen pushed flows.
    GoRoute(path: AppRoutes.upload, builder: (_, _) => const UploadScreen()),
    GoRoute(
      path: '${AppRoutes.processing}/:id',
      builder: (_, s) => AiProcessingScreen(projectId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '${AppRoutes.wizard}/:id',
      builder: (_, s) => AiWizardScreen(projectId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '${AppRoutes.editor}/:id',
      builder: (_, s) => EditorScreen(projectId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '${AppRoutes.export}/:id',
      builder: (_, s) => ExportScreen(projectId: s.pathParameters['id']!),
    ),

    // Bottom-nav shell.
    StatefulShellRoute.indexedStack(
      builder: (_, _, navShell) => AppShell(navigationShell: navShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.templates, builder: (_, _) => const TemplatesScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.ai, builder: (_, _) => const AiAssistantScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.projects, builder: (_, _) => const ProjectsScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen())],
        ),
      ],
    ),
  ],
);
