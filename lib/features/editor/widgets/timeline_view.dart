import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/timeline.dart';
import '../editor_theme.dart';

/// Horizontally-scrolling timeline strip (Twintra style): a time ruler above a
/// clip track, with captions remapped onto the output timeline and a white
/// playhead. Tap/drag to seek, tap a clip to select.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.timeline,
    required this.positionMs,
    required this.pxPerSecond,
    required this.selectedClipId,
    required this.onSeek,
    required this.onSelectClip,
  });

  final Timeline timeline;
  final int positionMs;
  final double pxPerSecond;
  final String? selectedClipId;
  final ValueChanged<int> onSeek;
  final ValueChanged<String> onSelectClip;

  static const double _clipH = 52;
  static const double _capH = 22;

  int get _outMs => math.max(timeline.playbackDurationMs, 1000);
  double get _contentW => _outMs / 1000 * pxPerSecond;

  int _msFromDx(double dx) => ((dx / pxPerSecond) * 1000).round().clamp(0, _outMs);

  @override
  Widget build(BuildContext context) {
    final playheadX = positionMs / 1000 * pxPerSecond;
    return Container(
      color: Ed.bg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _contentW + 48,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onSeek(_msFromDx(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) => onSeek(_msFromDx(d.localPosition.dx)),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _ruler(),
                const SizedBox(height: 4),
                _videoTrack(),
                const SizedBox(height: 4),
                _captionTrack(),
              ]),
              // White playhead line + knob.
              Positioned(
                left: playheadX.clamp(0, _contentW),
                top: 18,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: (playheadX - 5).clamp(0, _contentW),
                top: 14,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ruler() {
    final totalSec = math.max(_outMs / 1000, 1).ceil();
    return SizedBox(
      height: 18,
      child: Row(children: [
        for (var s = 0; s <= totalSec; s += 2)
          SizedBox(
            width: pxPerSecond * 2,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 1, height: 6, color: Ed.muted),
              const SizedBox(width: 3),
              Text(Formatters.duration(s * 1000), style: const TextStyle(fontSize: 9, color: Ed.muted)),
            ]),
          ),
      ]),
    );
  }

  Widget _videoTrack() {
    final blocks = <Widget>[];
    var cursor = 0.0;
    for (final clip in timeline.clips) {
      final w = math.max(clip.playbackMs / 1000 * pxPerSecond, 28.0);
      final selected = clip.id == selectedClipId;
      blocks.add(Positioned(
        left: cursor,
        top: 0,
        height: _clipH,
        width: w - 2,
        child: GestureDetector(
          onTap: () => onSelectClip(clip.id),
          child: Container(
            decoration: BoxDecoration(
              color: Ed.barAlt,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: selected ? Ed.accent : Colors.white12, width: selected ? 2 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            child: Row(children: [
              const Icon(Icons.movie_creation_outlined, size: 14, color: Ed.icon),
              const SizedBox(width: 4),
              if (clip.speed != 1.0)
                Text('${clip.speed}x',
                    style: const TextStyle(color: Ed.accent, fontSize: 10, fontWeight: FontWeight.w700))
              else
                Text(Formatters.duration(clip.playbackMs),
                    style: const TextStyle(color: Ed.muted, fontSize: 10)),
            ]),
          ),
        ),
      ));
      cursor += w;
    }
    return SizedBox(height: _clipH, width: _contentW, child: Stack(children: blocks));
  }

  Widget _captionTrack() {
    final blocks = <Widget>[];
    var cursor = 0;
    for (final clip in timeline.clips) {
      for (final cap in timeline.captions) {
        if (cap.endMs <= clip.startMs || cap.startMs >= clip.endMs) continue;
        final s = cap.startMs.clamp(clip.startMs, clip.endMs);
        final e = cap.endMs.clamp(clip.startMs, clip.endMs);
        final outS = cursor + ((s - clip.startMs) / clip.speed).round();
        final outE = cursor + ((e - clip.startMs) / clip.speed).round();
        blocks.add(Positioned(
          left: outS / 1000 * pxPerSecond,
          top: 0,
          height: _capH,
          width: math.max((outE - outS) / 1000 * pxPerSecond, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: Ed.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: Text(cap.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ));
      }
      cursor += clip.playbackMs;
    }
    return SizedBox(height: _capH, width: _contentW, child: Stack(children: blocks));
  }
}
