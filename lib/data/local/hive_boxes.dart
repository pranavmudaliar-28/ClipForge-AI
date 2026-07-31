import 'package:hive_flutter/hive_flutter.dart';

/// Hive setup. Projects are stored as plain JSON maps (no generated adapters),
/// which keeps the build free of codegen.
abstract final class HiveBoxes {
  static const String projects = 'projects';
  static const String settings = 'settings';

  // settings keys
  static const String onboardingComplete = 'onboarding_complete';
  static const String authUser = 'auth_user';
  static const String themeMode = 'theme_mode'; // 'system' | 'light' | 'dark'

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(projects),
      Hive.openBox(settings),
    ]);
  }

  static Box get projectsBox => Hive.box(projects);
  static Box get settingsBox => Hive.box(settings);

  const HiveBoxes._();
}
