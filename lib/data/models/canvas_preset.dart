import 'package:flutter/material.dart';

/// A social-platform canvas preset (aspect ratio + export resolution).
class CanvasPreset {
  const CanvasPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.w,
    required this.h,
    required this.exportW,
    required this.exportH,
    this.recommended = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final int w; // aspect width
  final int h; // aspect height
  final int exportW; // 1080p-class export width
  final int exportH;
  final bool recommended;

  double get ratio => w / h;
  String get ratioLabel => '$w:$h';
  String get resolutionLabel => '$exportW×$exportH';

  static const custom = CanvasPreset(
    id: 'custom', label: 'Custom', icon: Icons.tune_rounded,
    w: 9, h: 16, exportW: 1080, exportH: 1920,
  );

  /// Platform presets shown in the canvas tool.
  static const List<CanvasPreset> all = [
    CanvasPreset(id: 'yt_shorts', label: 'YouTube Shorts', icon: Icons.play_circle_fill_rounded,
        w: 9, h: 16, exportW: 1080, exportH: 1920, recommended: true),
    CanvasPreset(id: 'tiktok', label: 'TikTok', icon: Icons.music_note_rounded,
        w: 9, h: 16, exportW: 1080, exportH: 1920),
    CanvasPreset(id: 'ig_reel', label: 'Instagram Reel', icon: Icons.camera_rounded,
        w: 9, h: 16, exportW: 1080, exportH: 1920),
    CanvasPreset(id: 'ig_story', label: 'Instagram Story', icon: Icons.amp_stories_rounded,
        w: 9, h: 16, exportW: 1080, exportH: 1920),
    CanvasPreset(id: 'ig_portrait', label: 'Instagram Portrait', icon: Icons.crop_portrait_rounded,
        w: 4, h: 5, exportW: 1080, exportH: 1350),
    CanvasPreset(id: 'ig_square', label: 'Instagram Square', icon: Icons.crop_square_rounded,
        w: 1, h: 1, exportW: 1080, exportH: 1080),
    CanvasPreset(id: 'yt_video', label: 'YouTube Video', icon: Icons.smart_display_rounded,
        w: 16, h: 9, exportW: 1920, exportH: 1080),
    CanvasPreset(id: 'fb_reel', label: 'Facebook Reel', icon: Icons.facebook_rounded,
        w: 9, h: 16, exportW: 1080, exportH: 1920),
    CanvasPreset(id: 'fb_feed', label: 'Facebook Feed', icon: Icons.dynamic_feed_rounded,
        w: 4, h: 5, exportW: 1080, exportH: 1350),
    CanvasPreset(id: 'linkedin', label: 'LinkedIn Video', icon: Icons.work_rounded,
        w: 1, h: 1, exportW: 1080, exportH: 1080),
    CanvasPreset(id: 'x', label: 'X (Twitter)', icon: Icons.tag_rounded,
        w: 16, h: 9, exportW: 1920, exportH: 1080),
    CanvasPreset(id: 'pinterest', label: 'Pinterest', icon: Icons.push_pin_rounded,
        w: 2, h: 3, exportW: 1000, exportH: 1500),
    custom,
  ];

  static CanvasPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}
