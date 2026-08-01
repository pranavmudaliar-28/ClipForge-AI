import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/edit_settings.dart';
import '../data/models/project.dart';
import '../data/models/timeline.dart';
import 'app_providers.dart';
import 'projects_provider.dart';

@immutable
class EditorState {
  const EditorState({
    required this.projectId,
    required this.title,
    required this.timeline,
    required this.canvasId,
    required this.durationMs,
    this.selectedClipId,
    this.positionMs = 0,
    this.pxPerSecond = 80,
    this.past = const [],
    this.future = const [],
  });

  final String projectId;
  final String title;
  final Timeline timeline;
  final String canvasId;
  final int durationMs; // source duration
  final String? selectedClipId;
  final int positionMs; // playhead on the OUTPUT timeline
  final double pxPerSecond;
  final List<Timeline> past;
  final List<Timeline> future;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;
  int get outputMs => timeline.playbackDurationMs;

  EditorState copyWith({
    String? title,
    Timeline? timeline,
    String? canvasId,
    Object? selectedClipId = _sentinel,
    int? positionMs,
    double? pxPerSecond,
    List<Timeline>? past,
    List<Timeline>? future,
  }) {
    return EditorState(
      projectId: projectId,
      title: title ?? this.title,
      timeline: timeline ?? this.timeline,
      canvasId: canvasId ?? this.canvasId,
      durationMs: durationMs,
      selectedClipId:
          selectedClipId == _sentinel ? this.selectedClipId : selectedClipId as String?,
      positionMs: positionMs ?? this.positionMs,
      pxPerSecond: pxPerSecond ?? this.pxPerSecond,
      past: past ?? this.past,
      future: future ?? this.future,
    );
  }

  static const _sentinel = Object();
}

class EditorController extends StateNotifier<EditorState> {
  EditorController(this._ref, Project project)
      : super(EditorState(
          projectId: project.id,
          title: project.title,
          canvasId: project.canvasId,
          durationMs: project.durationMs,
          timeline: _initTimeline(project),
        ));

  final Ref _ref;

  static Timeline _initTimeline(Project p) {
    final t = p.timeline;
    if (t.clips.isNotEmpty) return t;
    final dur = t.durationMs > 0 ? t.durationMs : p.durationMs;
    return t.copyWith(
      durationMs: dur,
      clips: [Clip(id: 'clip_0', startMs: 0, endMs: dur, label: 'Clip')],
    );
  }

  // --- history --------------------------------------------------------------
  void _commit(Timeline next, {String? select}) {
    state = state.copyWith(
      past: [...state.past, state.timeline],
      future: const [],
      timeline: next,
      selectedClipId: select ?? state.selectedClipId,
    );
  }

  void undo() {
    if (!state.canUndo) return;
    final prev = state.past.last;
    state = state.copyWith(
      timeline: prev,
      past: state.past.sublist(0, state.past.length - 1),
      future: [state.timeline, ...state.future],
    );
  }

  void redo() {
    if (!state.canRedo) return;
    final next = state.future.first;
    state = state.copyWith(
      timeline: next,
      future: state.future.sublist(1),
      past: [...state.past, state.timeline],
    );
  }

  // --- selection / playhead -------------------------------------------------
  void select(String? clipId) => state = state.copyWith(selectedClipId: clipId);
  void seek(int ms) => state = state.copyWith(positionMs: ms.clamp(0, state.outputMs));
  void setZoom(double pxPerSecond) =>
      state = state.copyWith(pxPerSecond: pxPerSecond.clamp(20.0, 240.0));
  void rename(String title) => state = state.copyWith(title: title);
  void setCanvas(String canvasId) => state = state.copyWith(canvasId: canvasId);

  Clip? get _selected {
    final id = state.selectedClipId;
    if (id == null) return null;
    for (final c in state.timeline.clips) {
      if (c.id == id) return c;
    }
    return null;
  }

  // --- editing ops ----------------------------------------------------------
  /// Splits the clip under the playhead into two at that source position.
  void splitAtPlayhead() {
    final clips = state.timeline.clips;
    var outCursor = 0;
    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final clipOut = c.playbackMs;
      if (state.positionMs >= outCursor && state.positionMs < outCursor + clipOut) {
        final sourcePos = c.startMs + ((state.positionMs - outCursor) * c.speed).round();
        if (sourcePos <= c.startMs + 40 || sourcePos >= c.endMs - 40) return; // too close to edge
        final left = c.copyWith(endMs: sourcePos);
        final right = Clip(
          id: 'clip_${DateTime.now().microsecondsSinceEpoch}',
          startMs: sourcePos,
          endMs: c.endMs,
          label: c.label,
          track: c.track,
          speed: c.speed,
          sourcePath: c.sourcePath,
          hasAudio: c.hasAudio,
        );
        final next = [...clips]
          ..removeAt(i)
          ..insertAll(i, [left, right]);
        _commit(state.timeline.copyWith(clips: next), select: right.id);
        return;
      }
      outCursor += clipOut;
    }
  }

  void deleteSelected() {
    final sel = _selected;
    if (sel == null || state.timeline.clips.length <= 1) return;
    final next = state.timeline.clips.where((c) => c.id != sel.id).toList();
    _commit(state.timeline.copyWith(clips: next), select: null);
  }

  void duplicateSelected() {
    final sel = _selected;
    if (sel == null) return;
    final dup = Clip(
      id: 'clip_${DateTime.now().microsecondsSinceEpoch}',
      startMs: sel.startMs,
      endMs: sel.endMs,
      label: sel.label,
      track: sel.track,
      speed: sel.speed,
      sourcePath: sel.sourcePath,
      hasAudio: sel.hasAudio,
    );
    // Insert AFTER the clip the playhead currently falls in (CapCut/VN style —
    // the user scrubs to choose placement), not always right after the original.
    // Append if the playhead is past the end.
    final clips = state.timeline.clips;
    var cursor = 0;
    var insertAt = clips.length;
    for (var i = 0; i < clips.length; i++) {
      final pb = clips[i].playbackMs;
      if (state.positionMs >= cursor && state.positionMs < cursor + pb) {
        insertAt = i + 1;
        break;
      }
      cursor += pb;
    }
    final next = [...clips]..insert(insertAt, dup);
    _commit(state.timeline.copyWith(clips: next), select: dup.id);
  }

  /// Appends a clip cut from [sourcePath] to the end of the video track. A
  /// distinct [sourcePath] (different from the project's original) is exported
  /// for real via the composer's multi-input path. Backward-compatible: a clip
  /// whose [sourcePath] equals the project source falls back to input 0.
  ///
  /// Product decision: freshly-imported footage APPENDS to the end (predictable),
  /// whereas [duplicateSelected] inserts at the playhead (scrub to place).
  void addClip({required String sourcePath, required int sourceDurationMs, int track = 0, bool hasAudio = true}) {
    final newClip = Clip(
      id: 'clip_${DateTime.now().microsecondsSinceEpoch}',
      startMs: 0,
      endMs: sourceDurationMs.clamp(1, 1 << 31),
      label: 'Clip',
      track: track,
      sourcePath: sourcePath,
      hasAudio: hasAudio,
    );
    final next = [...state.timeline.clips, newClip];
    _commit(state.timeline.copyWith(clips: next), select: newClip.id);
  }

  void setSpeed(double speed) {
    final sel = _selected;
    if (sel == null) return;
    final next = state.timeline.clips
        .map((c) => c.id == sel.id ? c.copyWith(speed: speed.clamp(0.25, 4.0)) : c)
        .toList();
    _commit(state.timeline.copyWith(clips: next));
  }

  /// Trim the selected clip's in/out (ms are source positions).
  void trimSelected({int? inMs, int? outMs}) {
    final sel = _selected;
    if (sel == null) return;
    final ni = (inMs ?? sel.startMs).clamp(0, sel.endMs - 100);
    final no = (outMs ?? sel.endMs).clamp(ni + 100, state.durationMs);
    final next = state.timeline.clips
        .map((c) => c.id == sel.id ? c.copyWith(startMs: ni, endMs: no) : c)
        .toList();
    _commit(state.timeline.copyWith(clips: next));
  }

  // --- edit settings (color/filter/fx/text/audio/transition/cutout) ---------
  Timeline get timeline => state.timeline;
  EditSettings get settings => state.timeline.settings;

  /// [record]=false updates live (e.g. during a slider drag) without pushing an
  /// undo entry; call once with [record]=true on drag-end to snapshot.
  void _applySettings(EditSettings s, {bool record = true}) {
    final next = state.timeline.copyWith(settings: s);
    if (record) {
      _commit(next);
    } else {
      state = state.copyWith(timeline: next);
    }
  }

  void setColor(ColorAdjust c, {bool record = true}) => _applySettings(settings.copyWith(color: c), record: record);
  void setFilter(FilterPreset f) => _applySettings(settings.copyWith(filter: f));
  void setEffects(Effects e, {bool record = true}) => _applySettings(settings.copyWith(effects: e), record: record);
  void setAudio(AudioSettings a, {bool record = true}) => _applySettings(settings.copyWith(audio: a), record: record);
  void setTransition(TransitionType t, {int? ms}) =>
      _applySettings(settings.copyWith(transition: t, transitionMs: ms ?? settings.transitionMs));
  void setCutout(Cutout c, {bool record = true}) => _applySettings(settings.copyWith(cutout: c), record: record);
  void addText(TextOverlay t) => _applySettings(settings.copyWith(texts: [...settings.texts, t]));
  void updateText(TextOverlay t, {bool record = true}) =>
      _applySettings(settings.copyWith(texts: settings.texts.map((x) => x.id == t.id ? t : x).toList()), record: record);
  void removeText(String id) =>
      _applySettings(settings.copyWith(texts: settings.texts.where((x) => x.id != id).toList()));

  /// Real silence removal: run ffmpeg `silencedetect`, invert the silent spans,
  /// and rebuild the clip list to keep only the spoken parts. Returns the number
  /// of silent gaps removed.
  Future<int> removeSilence({double thresholdDb = -30, double minSilenceSec = 0.6}) async {
    final proj = _ref.read(projectsProvider.notifier).byId(state.projectId);
    final src = proj?.sourcePath;
    if (src == null) return 0;
    final ffmpeg = _ref.read(ffmpegServiceProvider);

    final silences = <List<double>>[];
    double? curStart;
    await ffmpeg.run(
      "-i '$src' -af silencedetect=noise=${thresholdDb}dB:d=$minSilenceSec -f null -",
      totalMs: 0,
      onLog: (line) {
        final s = RegExp(r'silence_start:\s*([0-9.]+)').firstMatch(line);
        if (s != null) curStart = double.tryParse(s.group(1)!);
        final e = RegExp(r'silence_end:\s*([0-9.]+)').firstMatch(line);
        if (e != null && curStart != null) {
          silences.add([curStart!, double.parse(e.group(1)!)]);
          curStart = null;
        }
      },
    );
    if (silences.isEmpty) return 0;

    final durSec = state.durationMs / 1000.0;
    final kept = <List<int>>[];
    var cursor = 0.0;
    for (final sil in silences) {
      final s = sil[0].clamp(0.0, durSec), e = sil[1].clamp(0.0, durSec);
      if (s - cursor > 0.2) kept.add([(cursor * 1000).round(), (s * 1000).round()]);
      cursor = e;
    }
    if (durSec - cursor > 0.2) kept.add([(cursor * 1000).round(), (durSec * 1000).round()]);
    if (kept.isEmpty) return 0;

    final clips = [
      for (var i = 0; i < kept.length; i++)
        Clip(id: 'clip_sil_$i', startMs: kept[i][0], endMs: kept[i][1], label: 'Scene ${i + 1}'),
    ];
    _commit(state.timeline.copyWith(clips: clips), select: null);
    return silences.length;
  }

  // --- persistence ----------------------------------------------------------
  Future<void> save() async {
    final proj = _ref.read(projectsProvider.notifier).byId(state.projectId);
    if (proj == null) return;
    await _ref.read(projectsProvider.notifier).upsert(
          proj.copyWith(
            title: state.title,
            timeline: state.timeline,
            canvasId: state.canvasId,
            status: ProjectStatus.ready,
          ),
        );
  }
}

final editorControllerProvider =
    StateNotifierProvider.family<EditorController, EditorState, String>(
  (ref, projectId) {
    final project = ref.read(projectsProvider.notifier).byId(projectId);
    return EditorController(
      ref,
      project ??
          Project(
            id: projectId,
            title: 'Untitled',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: ProjectStatus.draft,
          ),
    );
  },
);
