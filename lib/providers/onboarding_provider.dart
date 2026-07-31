import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/hive_boxes.dart';

/// Whether the user has completed onboarding (persisted so it shows only once).
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier()
      : super(HiveBoxes.settingsBox.get(HiveBoxes.onboardingComplete, defaultValue: false) as bool);

  Future<void> complete() async {
    await HiveBoxes.settingsBox.put(HiveBoxes.onboardingComplete, true);
    state = true;
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) => OnboardingNotifier());
