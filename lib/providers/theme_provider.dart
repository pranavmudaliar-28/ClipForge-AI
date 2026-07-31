import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_boxes.dart';

/// App theme mode (system / light / dark), persisted to Hive.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_load());

  static ThemeMode _load() {
    final raw = HiveBoxes.settingsBox.get(HiveBoxes.themeMode, defaultValue: 'system') as String;
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await HiveBoxes.settingsBox.put(HiveBoxes.themeMode, mode.name);
  }

  Future<void> toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
