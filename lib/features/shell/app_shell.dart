import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_motion.dart';
import '../../core/design/app_theme.dart';

/// Bottom-nav scaffold hosting the five primary destinations; the center "AI"
/// tab is emphasised with the brand gradient.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Templates'),
    (Icons.auto_awesome, Icons.auto_awesome, 'AI'),
    (Icons.video_library_outlined, Icons.video_library_rounded, 'Projects'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  void _go(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _items.length; i++)
                  _NavButton(
                    item: _items[i],
                    selected: navigationShell.currentIndex == i,
                    emphasized: i == 2,
                    onTap: () => _go(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.emphasized,
    required this.onTap,
  });

  final (IconData, IconData, String) item;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (emphasized) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: c.brandGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 3),
            Text(item.$3, style: TextStyle(fontSize: 10, color: c.textTertiary)),
          ],
        ),
      );
    }

    final color = selected ? c.textPrimary : c.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.$2 : item.$1, color: color, size: 24),
          const SizedBox(height: 4),
          Text(item.$3, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: Motion.fast,
            height: 3,
            width: selected ? 16 : 0,
            decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ),
    );
  }
}
