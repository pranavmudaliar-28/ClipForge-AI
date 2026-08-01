import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/timeline.dart';
import '../editor_theme.dart';

/// Which kind of timeline item is currently highlighted (video clips + text are
/// tracked via the provider's selection; these cover the read-through layers).
enum _ItemKind { effect, audio, caption }

/// Multi-track timeline (Twintra style): a shared time ruler above one row per
/// video track index, then an effects row, one audio row per [AudioKind], and a
/// caption row — all sharing one horizontal (time) scroll, with a white playhead
/// pinned across every row. Scrolls horizontally by drag; tap to seek/select.
class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.timeline,
    required this.positionMs,
    required this.pxPerSecond,
    required this.selectedClipId,
    required this.selectedTextId,
    required this.onSeek,
    required this.onSelectClip,
    required this.onSelectText,
  });

  final Timeline timeline;
  final int positionMs;
  final double pxPerSecond;
  final String? selectedClipId;
  final String? selectedTextId;
  final ValueChanged<int> onSeek;
  final ValueChanged<String> onSelectClip;
  final ValueChanged<String> onSelectText;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  static const double _rulerH = 16;
  static const double _clipH = 46;
  static const double _fxH = 22;
  static const double _audH = 22;
  static const double _capH = 20;

  // Selection for non-clip layers (clips use the provider's selectedClipId).
  String? _selId;
  _ItemKind? _selKind;

  Timeline get _t => widget.timeline;
  double get _pps => widget.pxPerSecond;
  int get _outMs => math.max(_t.playbackDurationMs, 1000);
  double get _contentW => _outMs / 1000 * _pps;

  int _msFromDx(double dx) => ((dx / _pps) * 1000).round().clamp(0, _outMs);
  double _x(int ms) => ms / 1000 * _pps;

  void _selectItem(String id, _ItemKind kind) => setState(() {
        _selId = id;
        _selKind = kind;
      });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _ruler(),
      ..._videoRows(),
      if (_t.effects.isNotEmpty) _effectsRow(),
      ..._audioRows(),
      if (_t.captions.isNotEmpty) _captionRow(),
      if (_t.settings.texts.isNotEmpty) _textRow(),
    ];
    final playheadX = _x(widget.positionMs).clamp(0.0, _contentW);
    return Container(
      color: Ed.bg,
      child: SingleChildScrollView(
        // Vertical scroll so extra tracks never overflow the fixed strip height.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // NOTE(Bug 3): no drag-to-seek gesture here, so this ScrollView owns
          // horizontal drags (drag = scroll). Seeking is by tap only.
          // Future (playhead-arch): pin the playhead to the viewport and derive
          // positionMs from the scroll offset (Option B in master-prompt-fix-editor.md).
          child: SizedBox(
            width: _contentW + 48,
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
              Positioned(
                left: playheadX,
                top: _rulerH,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: (playheadX - 5).clamp(0.0, _contentW),
                top: _rulerH - 4,
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

  /// Transparent tap-to-seek background sized to a row.
  Widget _seekBg(double height) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => widget.onSeek(_msFromDx(d.localPosition.dx)),
        child: SizedBox(width: _contentW, height: height),
      );

  Widget _rowFrame(double height, List<Widget> blocks) => SizedBox(
        width: _contentW,
        height: height,
        child: Stack(children: [_seekBg(height), ...blocks]),
      );

  Widget _ruler() {
    final totalSec = math.max(_outMs / 1000, 1).ceil();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => widget.onSeek(_msFromDx(d.localPosition.dx)),
      child: SizedBox(
        height: _rulerH,
        width: _contentW,
        child: Row(children: [
          for (var s = 0; s <= totalSec; s += 2)
            SizedBox(
              width: _pps * 2,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 1, height: 6, color: Ed.muted),
                const SizedBox(width: 3),
                Text(Formatters.duration(s * 1000), style: const TextStyle(fontSize: 9, color: Ed.muted)),
              ]),
            ),
        ]),
      ),
    );
  }

  /// One row per distinct video-track index. Clip x-positions come from the
  /// global output order (clips concat in list order); [Clip.track] chooses row.
  List<Widget> _videoRows() {
    final byTrack = <int, List<_Placed>>{};
    var cursor = 0.0;
    for (final clip in _t.clips) {
      final w = math.max(clip.playbackMs / 1000 * _pps, 28.0);
      (byTrack[clip.track] ??= []).add(_Placed(clip.id, cursor, w, clip));
      cursor += w;
    }
    final indexes = byTrack.keys.toList()..sort();
    return [for (final ti in indexes) _videoRow(byTrack[ti]!)];
  }

  Widget _videoRow(List<_Placed> placed) {
    final blocks = <Widget>[];
    for (final p in placed) {
      final clip = p.clip;
      final selected = clip.id == widget.selectedClipId;
      blocks.add(Positioned(
        left: p.left,
        top: 2,
        height: _clipH - 4,
        width: p.width - 2,
        child: GestureDetector(
          onTap: () {
            widget.onSelectClip(clip.id);
            setState(() {
              _selId = null;
              _selKind = null;
            });
          },
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
                Text('${clip.speed}x', style: const TextStyle(color: Ed.accent, fontSize: 10, fontWeight: FontWeight.w700))
              else
                Text(Formatters.duration(clip.playbackMs), style: const TextStyle(color: Ed.muted, fontSize: 10)),
            ]),
          ),
        ),
      ));
    }
    return _rowFrame(_clipH, blocks);
  }

  Widget _effectsRow() {
    final blocks = <Widget>[
      for (final e in _t.effects)
        _layerBlock(
          id: e.id,
          kind: _ItemKind.effect,
          left: _x(e.startMs),
          width: math.max(_x(e.endMs) - _x(e.startMs), 16),
          height: _fxH,
          color: _fxColor(e.kind),
          label: e.label,
        ),
    ];
    return _rowFrame(_fxH, blocks);
  }

  /// One row per [AudioKind] present (Music / Voice / SFX are conceptually
  /// separate tracks even though they share the [AudioLayer] model).
  List<Widget> _audioRows() {
    final byKind = <AudioKind, List<AudioLayer>>{};
    for (final a in _t.audio) {
      (byKind[a.kind] ??= []).add(a);
    }
    final kinds = byKind.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    return [
      for (final k in kinds)
        _rowFrame(_audH, [
          for (final a in byKind[k]!)
            _layerBlock(
              id: a.id,
              kind: _ItemKind.audio,
              left: _x(a.startMs),
              width: math.max(_x(a.endMs) - _x(a.startMs), 16),
              height: _audH,
              color: _audColor(k),
              label: a.label,
              icon: _audIcon(k),
            ),
        ]),
    ];
  }

  Widget _captionRow() {
    final blocks = <Widget>[];
    var cursor = 0;
    for (final clip in _t.clips) {
      for (final cap in _t.captions) {
        if (cap.endMs <= clip.startMs || cap.startMs >= clip.endMs) continue;
        final cs = cap.startMs.clamp(clip.startMs, clip.endMs);
        final ce = cap.endMs.clamp(clip.startMs, clip.endMs);
        final os = cursor + ((cs - clip.startMs) / clip.speed).round();
        final oe = cursor + ((ce - clip.startMs) / clip.speed).round();
        blocks.add(_captionBlock('${cap.id}_$os', os, oe, cap.text));
      }
      cursor += clip.playbackMs;
    }
    return _rowFrame(_capH, blocks);
  }

  Widget _captionBlock(String id, int os, int oe, String text) {
    final selected = _selKind == _ItemKind.caption && _selId == id;
    return Positioned(
      left: _x(os),
      top: 1,
      height: _capH - 2,
      width: math.max(_x(oe) - _x(os), 16),
      child: GestureDetector(
        onTap: () => _selectItem(id, _ItemKind.caption),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Ed.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(5),
            border: selected ? Border.all(color: Colors.white, width: 1.4) : null,
          ),
          alignment: Alignment.centerLeft,
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  /// Text overlays as real time-ranged blocks (positioned by [TextOverlay.startMs],
  /// width by its window). Tapping selects — synced with the canvas via the
  /// provider's selection. Open-ended text spans to the timeline end.
  Widget _textRow() {
    final blocks = <Widget>[];
    for (final t in _t.settings.texts) {
      final end = t.endMs > t.startMs ? t.endMs : _outMs;
      final left = _x(t.startMs);
      final width = math.max(_x(end) - left, 24.0);
      final selected = widget.selectedTextId == t.id;
      final label = t.text.trim().isEmpty ? 'Text' : t.text.trim();
      blocks.add(Positioned(
        left: left,
        top: 1,
        height: _capH - 2,
        width: width,
        child: GestureDetector(
          onTap: () => widget.onSelectText(t.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.9), // magenta = text
              borderRadius: BorderRadius.circular(5),
              border: selected ? Border.all(color: Colors.white, width: 1.4) : null,
            ),
            alignment: Alignment.centerLeft,
            child: Row(children: [
              const Icon(Icons.text_fields_rounded, size: 11, color: Colors.white),
              const SizedBox(width: 3),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ));
    }
    return _rowFrame(_capH, blocks);
  }

  Widget _layerBlock({
    required String id,
    required _ItemKind kind,
    required double left,
    required double width,
    required double height,
    required Color color,
    required String label,
    IconData? icon,
  }) {
    final selected = _selKind == kind && _selId == id;
    return Positioned(
      left: left,
      top: 1,
      height: height - 2,
      width: width,
      child: GestureDetector(
        onTap: () => _selectItem(id, kind),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(5),
            border: selected ? Border.all(color: Colors.white, width: 1.4) : null,
          ),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            if (icon != null) ...[Icon(icon, size: 11, color: Colors.black), const SizedBox(width: 3)],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  Color _fxColor(EffectKind k) => switch (k) {
        EffectKind.zoom => const Color(0xFF7C5CFF),
        EffectKind.transition => Ed.accent,
        EffectKind.colorGrade => Ed.amber1,
        EffectKind.bRoll => const Color(0xFF30D158),
      };

  Color _audColor(AudioKind k) => switch (k) {
        AudioKind.music => Ed.addBlue,
        AudioKind.voice => const Color(0xFF14B8A6),
        AudioKind.sfx => const Color(0xFFFF6B6B),
      };

  IconData _audIcon(AudioKind k) => switch (k) {
        AudioKind.music => Icons.music_note_rounded,
        AudioKind.voice => Icons.mic_rounded,
        AudioKind.sfx => Icons.graphic_eq_rounded,
      };
}

/// A clip placed on the output timeline (x/width in px) for rendering.
class _Placed {
  const _Placed(this.id, this.left, this.width, this.clip);
  final String id;
  final double left;
  final double width;
  final Clip clip;
}
