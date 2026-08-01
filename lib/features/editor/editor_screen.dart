import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/canvas_preset.dart';
import '../../data/models/edit_settings.dart';
import '../../data/models/overlay_object.dart';
import '../../data/models/timeline.dart';
import '../../providers/app_providers.dart';
import '../../providers/editor_provider.dart';
import '../../providers/projects_provider.dart';
import 'editor_theme.dart';
import 'widgets/timeline_view.dart';
import 'widgets/tool_sheets.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _failed = false;
  bool _seeking = false;

  // Which clip (list order) is currently playing — drives gap-skipping during
  // playback so non-contiguous clips (remove-silence / delete / reorder) play
  // back correctly instead of running straight through the source.
  int _activeClipIndex = 0;
  String? _projectSourcePath; // the single source the preview controller plays

  // Canvas selection-gizmo gesture state (captured at pan start).
  // _gizMode: 0 none · 1 move · 2 scale · 3 rotate.
  int _gizMode = 0;
  Offset _gizStartPointer = Offset.zero;
  double _gizStartX = 0.5, _gizStartY = 0.5, _gizStartScale = 34, _gizStartRot = 0;
  double _gizStartDist = 1, _gizStartAngle = 0;
  bool _gizChanged = false;

  EditorController get _ctrl => ref.read(editorControllerProvider(widget.projectId).notifier);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final project = ref.read(projectsProvider.notifier).byId(widget.projectId);
    final path = project?.sourcePath;
    if (path == null || !File(path).existsSync()) {
      setState(() => _failed = true);
      return;
    }
    _projectSourcePath = path;
    final v = VideoPlayerController.file(File(path));
    try {
      await v.initialize();
      await v.setLooping(true);
      v.addListener(_onTick);
      if (!mounted) return;
      setState(() {
        _video = v;
        _ready = true;
      });
    } catch (_) {
      setState(() => _failed = true);
    }
  }

  // --- playhead <-> source mapping -----------------------------------------
  int _outputToSource(int outMs, List<Clip> clips) {
    var cursor = 0;
    for (final c in clips) {
      if (outMs >= cursor && outMs < cursor + c.playbackMs) {
        return c.startMs + ((outMs - cursor) * c.speed).round();
      }
      cursor += c.playbackMs;
    }
    return clips.isEmpty ? outMs : clips.last.endMs;
  }

  /// Which clip (list order) an output-timeline position falls in.
  int _clipIndexForOutput(int outMs, List<Clip> clips) {
    var cursor = 0;
    for (var i = 0; i < clips.length; i++) {
      final pb = clips[i].playbackMs;
      if (outMs >= cursor && outMs < cursor + pb) return i;
      cursor += pb;
    }
    return clips.isEmpty ? 0 : clips.length - 1;
  }

  /// Output position derived from the *active* clip + the raw player position —
  /// correct even when clips repeat a source range (duplicate) or are reordered
  /// (unlike [_sourceToOutput], which matches the first source range).
  int _outputForActive(int srcMs, List<Clip> clips) {
    if (clips.isEmpty) return 0;
    final i = _activeClipIndex.clamp(0, clips.length - 1);
    var base = 0;
    for (var k = 0; k < i; k++) {
      base += clips[k].playbackMs;
    }
    final c = clips[i];
    final within = ((srcMs - c.startMs) / c.speed).round().clamp(0, c.playbackMs);
    return base + within;
  }

  /// The preview controller only plays the project source; added-source clips
  /// can't be shown by it (export is still exact).
  bool _isProjectSource(Clip c) => c.sourcePath == null || c.sourcePath == _projectSourcePath;

  void _onTick() {
    final v = _video;
    if (v == null || !v.value.isInitialized || _seeking) return;
    if (!v.value.isPlaying) return;

    final state = ref.read(editorControllerProvider(widget.projectId));
    final clips = state.timeline.clips;
    if (clips.isEmpty) return;
    final i = _activeClipIndex.clamp(0, clips.length - 1);
    final cur = clips[i];
    final srcMs = v.value.position.inMilliseconds;

    // Playback ran past the current kept clip's source window → jump to the next
    // clip in list order (skipping any gap), or stop at the timeline end.
    if (srcMs >= cur.endMs) {
      if (i + 1 >= clips.length) {
        v.pause();
        _ctrl.seek(state.outputMs);
        if (mounted) setState(() {});
        return;
      }
      _activeClipIndex = i + 1;
      final next = clips[_activeClipIndex];
      if (_isProjectSource(next)) {
        _seeking = true;
        v.seekTo(Duration(milliseconds: next.startMs)).then((_) => _seeking = false);
      } else {
        // Can't preview added-source footage with the project-source player.
        v.pause();
        if (mounted) setState(() {});
      }
      _ctrl.seek(_outputForActive(next.startMs, clips));
      return;
    }

    _ctrl.seek(_outputForActive(srcMs, clips));
  }

  Future<void> _seekToOutput(int outMs) async {
    final v = _video;
    if (v == null) return;
    final clips = ref.read(editorControllerProvider(widget.projectId)).timeline.clips;
    _activeClipIndex = _clipIndexForOutput(outMs, clips);
    _seeking = true;
    _ctrl.seek(outMs);
    await v.seekTo(Duration(milliseconds: _outputToSource(outMs, clips)));
    _seeking = false;
  }

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    HapticFeedback.selectionClick();
    if (v.value.isPlaying) {
      v.pause();
    } else {
      // Resume from whichever clip the playhead is currently on.
      final st = ref.read(editorControllerProvider(widget.projectId));
      _activeClipIndex = _clipIndexForOutput(st.positionMs, st.timeline.clips);
      v.play();
    }
    setState(() {});
  }

  Future<void> _exit() async {
    await _ctrl.save();
    if (mounted) context.pop();
  }

  Future<void> _openExport() async {
    await _ctrl.save();
    if (!mounted) return;
    context.push(AppRoutes.exportFor(widget.projectId));
  }

  /// Pick a video from the device, probe its real duration, and append it as a
  /// new clip. Distinct source files export for real via the composer's
  /// multi-input path. (This is "add clip" — duplication lives in the toolbar.)
  Future<void> _addClip() async {
    HapticFeedback.selectionClick();
    final res = await FilePicker.platform.pickFiles(type: FileType.video);
    final path = res?.files.single.path;
    if (path == null) return; // user cancelled
    if (!File(path).existsSync()) {
      if (mounted) showAppToast(context, 'That file could not be found', type: ToastType.error);
      return;
    }
    // Probe duration with video_player (already a dependency — no ffprobe call).
    final probe = VideoPlayerController.file(File(path));
    var durMs = 0;
    try {
      await probe.initialize();
      durMs = probe.value.duration.inMilliseconds;
    } catch (_) {
      durMs = 0;
    } finally {
      await probe.dispose();
    }
    if (durMs <= 0) {
      if (mounted) showAppToast(context, "Couldn't read that video's length", type: ToastType.error);
      return;
    }
    // Probe for an audio track so the composer can synthesize silence for a
    // muted source instead of failing the concat on export.
    final hasAudio = await ref.read(ffmpegServiceProvider).hasAudioStream(path);
    _ctrl.addClip(sourcePath: path, sourceDurationMs: durMs, hasAudio: hasAudio);
    if (mounted) showAppToast(context, 'Clip added', type: ToastType.success);
  }

  /// Picks an image and returns (path, aspect=width/height), or null if cancelled.
  Future<(String, double)?> _pickImageWithAspect() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = res?.files.single.path;
    if (path == null || !File(path).existsSync()) return null;
    var aspect = 1.0;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (img.height > 0) aspect = img.width / img.height;
      img.dispose();
    } catch (_) {}
    return (path, aspect);
  }

  /// Rasterizes an emoji glyph to a square PNG in app documents (persistent so it
  /// survives for export), returning its path. No bundled sticker assets needed.
  Future<String> _renderEmojiPng(String emoji, {int size = 256}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size * 0.78)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    picture.dispose();
    final dir = await getApplicationDocumentsDirectory();
    final stickers = Directory('${dir.path}/stickers');
    if (!stickers.existsSync()) stickers.createSync(recursive: true);
    final file = File('${stickers.path}/sticker_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    return file.path;
  }

  Future<void> _addImageOverlay() async {
    HapticFeedback.selectionClick();
    final picked = await _pickImageWithAspect();
    if (picked == null) return;
    _ctrl.addOverlay(OverlayObject(
      id: 'ov_${DateTime.now().microsecondsSinceEpoch}',
      kind: OverlayKind.image,
      sourcePath: picked.$1,
      aspect: picked.$2,
      wNorm: 0.5,
    ));
    if (mounted) showAppToast(context, 'Image added', type: ToastType.success);
  }

  Future<void> _addSticker() async {
    HapticFeedback.selectionClick();
    final emoji = await showStickerPicker(context);
    if (emoji == null) return;
    final path = await _renderEmojiPng(emoji);
    _ctrl.addOverlay(OverlayObject(
      id: 'ov_${DateTime.now().microsecondsSinceEpoch}',
      kind: OverlayKind.sticker,
      sourcePath: path,
      aspect: 1.0,
      wNorm: 0.25,
    ));
    if (mounted) showAppToast(context, 'Sticker added', type: ToastType.success);
  }

  Future<void> _replaceOverlay() async {
    final o = _ctrl.selectedOverlay;
    if (o == null) return;
    if (o.kind == OverlayKind.sticker) {
      final emoji = await showStickerPicker(context);
      if (emoji == null) return;
      final path = await _renderEmojiPng(emoji);
      _ctrl.updateOverlay(o.copyWith(sourcePath: path, aspect: 1.0));
    } else {
      final picked = await _pickImageWithAspect();
      if (picked == null) return;
      _ctrl.updateOverlay(o.copyWith(sourcePath: picked.$1, aspect: picked.$2));
    }
  }

  void _openFullscreen(CanvasPreset canvas, EditorState state) {
    final v = _video;
    if (v == null) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Center(child: AspectRatio(aspectRatio: canvas.ratio, child: _previewContent(canvas, state))),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.fullscreen_exit_rounded, color: Ed.icon, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ]),
      ),
    ));
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider(widget.projectId));
    final canvas = CanvasPreset.byId(state.canvasId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: Ed.bg,
        body: SafeArea(
          child: Column(children: [
            _TopBar(title: state.title, onBack: _exit, onRename: _ctrl.rename, onExport: _openExport),
            Expanded(child: _preview(canvas, state)),
            _transport(state, canvas),
            _timecodeBar(state),
            _timelineBlock(state),
            const Divider(height: 1, thickness: 1, color: Ed.hair),
            // Toolbar is contextual: its buttons change with what's selected.
            // The ValueKey resets the horizontal scroll when the context switches.
            _Toolbar(key: ValueKey(state.selection.kind), tools: _toolsFor(state.selection, state)),
          ]),
        ),
      ),
    );
  }

  /// The bottom toolbar changes with the current selection (CapCut-style). Only
  /// tools with a real action for that context are shown — no dead buttons.
  List<(IconData, String, VoidCallback)> _toolsFor(Selection sel, EditorState state) {
    switch (sel.kind) {
      case SelectionKind.clip:
        return _clipTools(state);
      case SelectionKind.text:
        return _textTools();
      case SelectionKind.overlay:
        return _overlayTools();
      case SelectionKind.none:
      case SelectionKind.caption:
      case SelectionKind.audioLayer:
        return _globalTools(state);
    }
  }

  // No selection → project-level tools (add media/overlay/sticker/text/audio, looks, AI).
  List<(IconData, String, VoidCallback)> _globalTools(EditorState state) => [
        (Icons.add_photo_alternate_outlined, 'Add', _addClip),
        (Icons.image_outlined, 'Overlay', _addImageOverlay),
        (Icons.emoji_emotions_outlined, 'Sticker', _addSticker),
        (Icons.text_fields_rounded, 'Text', () => showTextSheet(context, _ctrl)),
        (Icons.volume_up_outlined, 'Audio', () => showAudioSheet(context, _ctrl)),
        (Icons.crop_free_rounded, 'Canvas', () => showCanvasSheet(context, state.canvasId, _ctrl.setCanvas)),
        (Icons.auto_awesome_rounded, 'Filter', () => showFilterSheet(context, _ctrl)),
        (Icons.tune_rounded, 'Adjust', () => showAdjustSheet(context, _ctrl)),
        (Icons.blur_on_rounded, 'Effects', () => showEffectsSheet(context, _ctrl)),
        (Icons.subtitles_outlined, 'Captions', () => showCaptionsSheet(context, _ctrl)),
        (Icons.auto_fix_high_rounded, 'AI Tools', _openAiTools),
      ];

  // An image/sticker overlay is selected → edit / replace / duplicate / delete.
  // (Move/scale/rotate happen on the canvas gizmo.)
  List<(IconData, String, VoidCallback)> _overlayTools() => [
        (Icons.tune_rounded, 'Edit', () => showOverlaySheet(context, _ctrl)),
        (Icons.swap_horiz_rounded, 'Replace', _replaceOverlay),
        (Icons.copy_rounded, 'Duplicate', () {
          final o = _ctrl.selectedOverlay;
          if (o != null) _ctrl.duplicateOverlay(o.id);
        }),
        (Icons.delete_outline_rounded, 'Delete', () {
          final o = _ctrl.selectedOverlay;
          if (o != null) _ctrl.removeOverlay(o.id);
        }),
      ];

  // A video clip is selected → clip operations + timeline-wide looks.
  List<(IconData, String, VoidCallback)> _clipTools(EditorState state) => [
        (Icons.content_cut_rounded, 'Split', () {
          _ctrl.splitAtPlayhead();
          HapticFeedback.mediumImpact();
        }),
        (Icons.straighten_rounded, 'Trim', () => showTrimSheet(context, _ctrl)),
        (Icons.speed_rounded, 'Speed', () => showSpeedSheet(context, _ctrl.selectedClip?.speed ?? 1.0, _ctrl.setSpeed)),
        (Icons.volume_up_outlined, 'Volume', () => showClipVolumeSheet(context, _ctrl)),
        (Icons.crop_rotate_rounded, 'Transform', () => showClipTransformSheet(context, _ctrl)),
        (Icons.copy_rounded, 'Duplicate', _ctrl.duplicateSelected),
        (Icons.delete_outline_rounded, 'Delete', _ctrl.deleteSelected),
        (Icons.auto_awesome_rounded, 'Filter', () => showFilterSheet(context, _ctrl)),
        (Icons.tune_rounded, 'Adjust', () => showAdjustSheet(context, _ctrl)),
        (Icons.blur_on_rounded, 'Effects', () => showEffectsSheet(context, _ctrl)),
        (Icons.blur_circular_outlined, 'Cutout', () => showCutoutSheet(context, _ctrl)),
        (Icons.swap_horiz_rounded, 'Transition', () => showTransitionSheet(context, _ctrl)),
      ];

  // A text overlay is selected → edit / timing / duplicate / delete.
  // (Animation is intentionally omitted — there is no real animated-text export
  // yet; it arrives in the Animation batch rather than as a dead button.)
  List<(IconData, String, VoidCallback)> _textTools() => [
        (Icons.edit_rounded, 'Edit', () {
          final cur = _ctrl.selectedText;
          if (cur != null) showTextSheet(context, _ctrl, editing: cur);
        }),
        (Icons.timer_outlined, 'Timing', () {
          final cur = _ctrl.selectedText;
          if (cur != null) showTextSheet(context, _ctrl, editing: cur, focusTiming: true);
        }),
        (Icons.copy_rounded, 'Duplicate', () {
          final cur = _ctrl.selectedText;
          if (cur != null) _ctrl.duplicateText(cur.id);
        }),
        (Icons.delete_outline_rounded, 'Delete', () {
          final cur = _ctrl.selectedText;
          if (cur != null) _ctrl.removeText(cur.id);
        }),
      ];

  void _openAiTools() {
    edShowPanel<void>(
      context,
      EdPanel(
        title: 'AI Tools',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _aiTile(Icons.content_cut_rounded, 'Remove silence', 'Detect and cut silent gaps', () async {
            Navigator.pop(context);
            showAppToast(context, 'Analyzing audio for silence…');
            final n = await _ctrl.removeSilence();
            if (mounted) {
              showAppToast(context, n > 0 ? 'Removed $n silent gap(s)' : 'No long silences found',
                  type: n > 0 ? ToastType.success : ToastType.info);
            }
          }),
          _aiTile(Icons.graphic_eq_rounded, 'Noise removal', 'Clean background hiss (on export)', () {
            _ctrl.setAudio(_ctrl.settings.audio.copyWith(denoise: true));
            Navigator.pop(context);
            showAppToast(context, 'Noise removal enabled', type: ToastType.success);
          }),
          _aiTile(Icons.record_voice_over_rounded, 'Voice enhance', 'Normalize + clarify speech (on export)', () {
            _ctrl.setAudio(_ctrl.settings.audio.copyWith(voiceEnhance: true));
            Navigator.pop(context);
            showAppToast(context, 'Voice enhance enabled', type: ToastType.success);
          }),
          _aiTile(Icons.crop_free_rounded, 'Auto reframe', 'Fit to a platform canvas', () {
            final current = ref.read(editorControllerProvider(widget.projectId)).canvasId;
            Navigator.pop(context);
            showCanvasSheet(context, current, _ctrl.setCanvas);
          }),
        ]),
      ),
    );
  }

  Widget _aiTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Ed.icon),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Ed.muted, fontSize: 12)),
      onTap: onTap,
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────
  Widget _preview(CanvasPreset canvas, EditorState state) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: AspectRatio(
        aspectRatio: canvas.ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _previewContent(canvas, state),
        ),
      ),
    );
  }

  Widget _previewContent(CanvasPreset canvas, EditorState state) {
    return LayoutBuilder(builder: (context, box) {
      final s = state.timeline.settings;
      Widget content;
      if (_ready && _video != null) {
        Widget v = FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _video!.value.size.width,
            height: _video!.value.size.height,
            child: VideoPlayer(_video!),
          ),
        );
        v = ColorFiltered(colorFilter: ColorFilter.matrix(s.previewMatrix()), child: v);
        if (s.previewBlurSigma > 0) {
          v = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: s.previewBlurSigma, sigmaY: s.previewBlurSigma),
            child: v,
          );
        }
        content = v;
      } else if (_failed) {
        content = const Center(child: Text('Preview unavailable', style: TextStyle(color: Ed.muted)));
      } else {
        content = const Center(child: CircularProgressIndicator(color: Ed.accent));
      }

      // Reflect the active project-source clip's flip/rotate live (approximate;
      // the single preview player can't show added-source clips — export is
      // exact). Volume/fade are audio-only, so preview-exempt.
      if (_ready && _video != null) {
        final active = _activeClip(state);
        if (active != null && (active.flipH || active.flipV || active.quarterTurns % 4 != 0)) {
          content = _clipTransform(content, active);
        }
      }

      final textScale = (box.maxHeight.isFinite && box.maxHeight > 0 && canvas.exportH > 0)
          ? box.maxHeight / canvas.exportH
          : 0.2;
      // Image/sticker overlays, drawn back-to-front by z; text sits above them.
      final overlays = [...state.timeline.overlays]..sort((a, b) => a.z.compareTo(b.z));
      // A selected text OR overlay drives the canvas gizmo.
      final hasGizmo =
          state.selection.kind == SelectionKind.text || state.selection.kind == SelectionKind.overlay;

      return GestureDetector(
        onTap: () {
          // Tapping empty canvas deselects; with nothing selected, play/pause.
          if (!state.selection.isNone) {
            _ctrl.clearSelection();
          } else {
            _togglePlay();
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          Container(color: Colors.black),
          content,
          if (s.effects.vignette > 0)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75 * s.effects.vignette)],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
          if (_video != null) _captionOverlay(state),
          // Play indicator is drawn BELOW the overlays/text so a centered element
          // isn't hidden behind it while paused; IgnorePointer so taps fall
          // through to play/select handlers.
          if (_video != null && !_video!.value.isPlaying)
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
              ),
            ),
          // Image/sticker overlays (below text), time-gated; tap selects.
          for (final o in overlays)
            if (_shouldShowOverlay(o, state)) _overlayDisplay(o, box),
          // Text overlays (rotation + opacity match export). Unselected is
          // time-gated; the selected one always shows so it stays editable.
          for (final t in s.texts)
            if (_shouldShowText(t, state)) _textDisplay(t, textScale),
          // Unified selection gizmo (canvas-spanning gesture layer + handles),
          // active while a text or overlay is selected.
          if (hasGizmo) _gizmoLayer(state, box, textScale),
        ]),
      );
    });
  }

  /// The clip under the playhead if it's a project-source clip (the only kind
  /// the single preview player can show), else null.
  Clip? _activeClip(EditorState state) {
    final clips = state.timeline.clips;
    if (clips.isEmpty) return null;
    final c = clips[_clipIndexForOutput(state.positionMs, clips)];
    return _isProjectSource(c) ? c : null;
  }

  /// Wraps the preview video with a clip's flip + 90° rotation (approximate).
  Widget _clipTransform(Widget child, Clip c) {
    var w = child;
    final turns = c.quarterTurns % 4;
    if (turns != 0) w = RotatedBox(quarterTurns: turns, child: w);
    if (c.flipH || c.flipV) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(c.flipH ? -1.0 : 1.0, c.flipV ? -1.0 : 1.0, 1.0),
        child: w,
      );
    }
    return w;
  }

  // ── Canvas overlays/text display + unified selection gizmo ──────────────────
  bool _shouldShowText(TextOverlay t, EditorState state) {
    if (state.selection.kind == SelectionKind.text && state.selection.id == t.id) return true;
    final end = t.effectiveEndMs(state.outputMs);
    return state.positionMs >= t.startMs && state.positionMs < end;
  }

  bool _shouldShowOverlay(OverlayObject o, EditorState state) {
    if (state.selection.kind == SelectionKind.overlay && state.selection.id == o.id) return true;
    final end = o.effectiveEndMs(state.outputMs);
    return state.positionMs >= o.startMs && state.positionMs < end;
  }

  Widget _textDisplay(TextOverlay t, double textScale) {
    final fontSize = (t.sizePt * textScale).clamp(8.0, 200.0);
    return Align(
      alignment: Alignment(t.xNorm * 2 - 1, t.yNorm * 2 - 1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _ctrl.selectText(t.id),
        child: Opacity(
          opacity: t.opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: t.rotationDeg * math.pi / 180,
            child: Text(
              t.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(int.parse('FF${t.colorHex.substring(1)}', radix: 16)),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayDisplay(OverlayObject o, BoxConstraints box) {
    final asp = o.aspect <= 0 ? 1.0 : o.aspect;
    final wpx = (o.wNorm * box.maxWidth).clamp(8.0, box.maxWidth * 2);
    final hpx = wpx / asp;
    final exists = o.sourcePath.isNotEmpty && File(o.sourcePath).existsSync();
    return Align(
      alignment: Alignment(o.xNorm * 2 - 1, o.yNorm * 2 - 1),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _ctrl.selectOverlay(o.id),
        child: Opacity(
          opacity: o.opacity.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: o.rotationDeg * math.pi / 180,
            child: SizedBox(
              width: wpx,
              height: hpx,
              child: exists
                  ? Image.file(File(o.sourcePath), fit: BoxFit.fill, filterQuality: FilterQuality.medium)
                  : const ColoredBox(color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }

  /// Measured pixel size of a text overlay at the current preview scale.
  Size _measureText(String text, double fontSize, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return tp.size;
  }

  /// On-canvas box (incl. padding) for a text overlay's gizmo + hit-test.
  Size _gizBoxSize(TextOverlay t, double textScale, BoxConstraints box) {
    final fontSize = (t.sizePt * textScale).clamp(8.0, 200.0);
    final sz = _measureText(t.text, fontSize, box.maxWidth);
    const pad = 10.0;
    return Size((sz.width + pad * 2).clamp(24.0, box.maxWidth), (sz.height + pad * 2).clamp(20.0, box.maxHeight));
  }

  /// On-canvas box (incl. padding) for an image/sticker overlay.
  Size _overlayBoxSize(OverlayObject o, BoxConstraints box) {
    final asp = o.aspect <= 0 ? 1.0 : o.aspect;
    final wpx = (o.wNorm * box.maxWidth).clamp(24.0, box.maxWidth);
    final hpx = (wpx / asp).clamp(20.0, box.maxHeight);
    const pad = 6.0;
    return Size(wpx + pad, hpx + pad);
  }

  /// Geometry of the currently-selected transformable object (text or overlay).
  ({Offset center, double rotDeg, Size box})? _gizGeom(EditorState state, BoxConstraints c, double textScale) {
    final w = c.maxWidth, h = c.maxHeight;
    if (state.selection.kind == SelectionKind.text) {
      final t = _ctrl.selectedText;
      if (t == null) return null;
      return (center: Offset(t.xNorm * w, t.yNorm * h), rotDeg: t.rotationDeg, box: _gizBoxSize(t, textScale, c));
    }
    if (state.selection.kind == SelectionKind.overlay) {
      final o = _ctrl.selectedOverlay;
      if (o == null) return null;
      return (center: Offset(o.xNorm * w, o.yNorm * h), rotDeg: o.rotationDeg, box: _overlayBoxSize(o, c));
    }
    return null;
  }

  Widget _gizmoLayer(EditorState state, BoxConstraints box, double textScale) {
    final g = _gizGeom(state, box, textScale);
    if (g == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final hit = _hitTest(d.localPosition, state, box, textScale);
          if (hit == null) {
            _ctrl.clearSelection();
          } else if (!(hit.kind == state.selection.kind && hit.id == state.selection.id)) {
            _ctrl.selectItem(hit.kind, hit.id!);
          }
        },
        onPanStart: (d) => _gizPanStart(state, d.localPosition, box, textScale),
        onPanUpdate: (d) => _gizPanUpdate(d.localPosition, box),
        onPanEnd: (_) => _gizPanEnd(),
        child: CustomPaint(
          painter: _GizmoPainter(center: g.center, boxSize: g.box, rotationDeg: g.rotDeg),
        ),
      ),
    );
  }

  /// Rotate a delta vector by -rot (into the object's un-rotated frame).
  Offset _unrotate(Offset d, double rot) {
    final ca = math.cos(rot), sa = math.sin(rot);
    return Offset(d.dx * ca + d.dy * sa, -d.dx * sa + d.dy * ca);
  }

  /// Topmost text (drawn above overlays), then topmost overlay (by z), whose
  /// rotated box contains [local]. Returns a Selection or null.
  Selection? _hitTest(Offset local, EditorState state, BoxConstraints box, double textScale) {
    final w = box.maxWidth, h = box.maxHeight;
    final texts = state.timeline.settings.texts;
    for (var i = texts.length - 1; i >= 0; i--) {
      final t = texts[i];
      final u = _unrotate(local - Offset(t.xNorm * w, t.yNorm * h), t.rotationDeg * math.pi / 180);
      final sz = _gizBoxSize(t, textScale, box);
      if (u.dx.abs() <= sz.width / 2 && u.dy.abs() <= sz.height / 2) return Selection(SelectionKind.text, t.id);
    }
    final overlays = [...state.timeline.overlays]..sort((a, b) => b.z.compareTo(a.z));
    for (final o in overlays) {
      final u = _unrotate(local - Offset(o.xNorm * w, o.yNorm * h), o.rotationDeg * math.pi / 180);
      final sz = _overlayBoxSize(o, box);
      if (u.dx.abs() <= sz.width / 2 && u.dy.abs() <= sz.height / 2) return Selection(SelectionKind.overlay, o.id);
    }
    return null;
  }

  double _selectedScaleRef() {
    final t = _ctrl.selectedText;
    if (t != null) return t.sizePt;
    final o = _ctrl.selectedOverlay;
    if (o != null) return o.wNorm;
    return 1;
  }

  void _gizPanStart(EditorState state, Offset local, BoxConstraints box, double textScale) {
    final g = _gizGeom(state, box, textScale);
    if (g == null) {
      _gizMode = 0;
      return;
    }
    final w = box.maxWidth, h = box.maxHeight;
    final center = g.center;
    final hw = g.box.width / 2, hh = g.box.height / 2;
    final u = _unrotate(local - center, g.rotDeg * math.pi / 180);
    _gizStartPointer = local;
    _gizStartX = center.dx / w;
    _gizStartY = center.dy / h;
    _gizStartScale = _selectedScaleRef();
    _gizStartRot = g.rotDeg;
    _gizStartDist = math.max((local - center).distance, 1);
    _gizStartAngle = math.atan2(local.dy - center.dy, local.dx - center.dx);
    _gizChanged = false;
    const slop = 24.0;
    // Rotation handle sits above top-centre (see _GizmoPainter).
    if ((u - Offset(0, -(hh + _kRotGap))).distance < slop) {
      _gizMode = 3;
    } else if ((u - Offset(-hw, -hh)).distance < slop ||
        (u - Offset(hw, -hh)).distance < slop ||
        (u - Offset(-hw, hh)).distance < slop ||
        (u - Offset(hw, hh)).distance < slop) {
      _gizMode = 2;
    } else if (u.dx.abs() <= hw && u.dy.abs() <= hh) {
      _gizMode = 1;
    } else {
      _gizMode = 0;
    }
  }

  void _gizPanUpdate(Offset local, BoxConstraints box) {
    if (_gizMode == 0) return;
    final t = _ctrl.selectedText;
    final o = t == null ? _ctrl.selectedOverlay : null;
    if (t == null && o == null) return;
    final w = box.maxWidth, h = box.maxHeight;
    final startCenter = Offset(_gizStartX * w, _gizStartY * h);
    _gizChanged = true;
    if (_gizMode == 1) {
      final nx = (_gizStartX + (local.dx - _gizStartPointer.dx) / w).clamp(0.02, 0.98);
      final ny = (_gizStartY + (local.dy - _gizStartPointer.dy) / h).clamp(0.02, 0.98);
      if (t != null) {
        _ctrl.updateText(t.copyWith(xNorm: nx, yNorm: ny), record: false);
      } else {
        _ctrl.updateOverlay(o!.copyWith(xNorm: nx, yNorm: ny), record: false);
      }
    } else if (_gizMode == 2) {
      final factor = (local - startCenter).distance / _gizStartDist;
      if (t != null) {
        _ctrl.updateText(t.copyWith(sizePt: (_gizStartScale * factor).clamp(12.0, 200.0)), record: false);
      } else {
        _ctrl.updateOverlay(o!.copyWith(wNorm: (_gizStartScale * factor).clamp(0.05, 2.0)), record: false);
      }
    } else if (_gizMode == 3) {
      final ang = math.atan2(local.dy - startCenter.dy, local.dx - startCenter.dx);
      var deg = _gizStartRot + (ang - _gizStartAngle) * 180 / math.pi;
      for (final snap in const [-360, -270, -180, -90, 0, 90, 180, 270, 360]) {
        if ((deg - snap).abs() < 4) {
          deg = snap.toDouble();
          break;
        }
      }
      if (t != null) {
        _ctrl.updateText(t.copyWith(rotationDeg: deg), record: false);
      } else {
        _ctrl.updateOverlay(o!.copyWith(rotationDeg: deg), record: false);
      }
    }
  }

  void _gizPanEnd() {
    final wasChanged = _gizChanged;
    _gizMode = 0;
    _gizChanged = false;
    if (!wasChanged) return;
    // Commit one undo entry for the whole gesture.
    final t = _ctrl.selectedText;
    if (t != null) {
      _ctrl.updateText(t);
      return;
    }
    final o = _ctrl.selectedOverlay;
    if (o != null) _ctrl.updateOverlay(o);
  }

  Widget _captionOverlay(EditorState state) {
    final v = _video!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: v,
      builder: (_, value, _) {
        final src = value.position.inMilliseconds;
        String text = '';
        for (final cap in state.timeline.captions) {
          if (src >= cap.startMs && src <= cap.endMs) {
            text = cap.text;
            break;
          }
        }
        if (text.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: const Alignment(0, 0.82),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(6)),
            child: Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)])),
          ),
        );
      },
    );
  }

  // ── Transport (undo/redo · play · fullscreen) ────────────────────────────────
  Widget _transport(EditorState state, CanvasPreset canvas) {
    final v = _video;
    final playing = v?.value.isPlaying ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _tIcon(Icons.undo_rounded, state.canUndo ? _ctrl.undo : null),
        _tIcon(Icons.redo_rounded, state.canRedo ? _ctrl.redo : null),
        const Spacer(),
        GestureDetector(
          onTap: v == null ? null : _togglePlay,
          child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Ed.accent, size: 34),
        ),
        const Spacer(),
        _tIcon(Icons.fullscreen_rounded, v == null ? null : () => _openFullscreen(canvas, state)),
      ]),
    );
  }

  Widget _tIcon(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: onTap == null ? Ed.muted : Ed.icon),
      splashRadius: 20,
    );
  }

  Widget _timecodeBar(EditorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Row(children: [
        Text(
          '${Formatters.timecode(state.positionMs)} / ${Formatters.timecode(state.outputMs)}',
          style: const TextStyle(
            color: Ed.icon,
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
  }

  // ── Timeline block (+ add button · clips · add music) ────────────────────────
  Widget _timelineBlock(EditorState state) {
    return SizedBox(
      height: 184,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 30, 8, 0),
          child: Tooltip(
            message: 'Add clip',
            child: Semantics(
              button: true,
              label: 'Add clip',
              child: GestureDetector(
                onTap: _addClip,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Ed.addBlue, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TimelineView(
                timeline: state.timeline,
                positionMs: state.positionMs,
                pxPerSecond: state.pxPerSecond,
                selectedClipId: state.selectedClipId,
                selectedTextId: state.selection.kind == SelectionKind.text ? state.selection.id : null,
                selectedOverlayId: state.selection.kind == SelectionKind.overlay ? state.selection.id : null,
                onSeek: _seekToOutput,
                onSelectClip: _ctrl.selectClip,
                onSelectText: _ctrl.selectText,
                onSelectOverlay: _ctrl.selectOverlay,
              ),
            ),
            _addMusicRow(state),
          ]),
        ),
      ]),
    );
  }

  Widget _addMusicRow(EditorState state) {
    final music = state.timeline.settings.audio.musicPath;
    return GestureDetector(
      onTap: () => showAudioSheet(context, _ctrl),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Ed.bar, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          const Icon(Icons.music_note_rounded, size: 15, color: Ed.icon),
          const SizedBox(width: 6),
          Text(
            music == null ? 'Add music' : music.split(Platform.pathSeparator).last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Ed.icon, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack, required this.onRename, required this.onExport});

  final String title;
  final VoidCallback onBack;
  final ValueChanged<String> onRename;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        Center(
          child: GestureDetector(
            onTap: () async {
              final controller = TextEditingController(text: title);
              final v = await showDialog<String>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Ed.panel,
                  title: const Text('Project name', style: TextStyle(color: Colors.white)),
                  content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
                  ],
                ),
              );
              if (v != null && v.trim().isNotEmpty) onRename(v.trim());
            },
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ed.title),
          ),
        ),
        Row(children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Ed.icon),
            splashRadius: 20,
          ),
          const Spacer(),
          IconButton(
            onPressed: onExport,
            icon: const Icon(Icons.ios_share_rounded, size: 22, color: Ed.icon),
            splashRadius: 20,
          ),
        ]),
      ]),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({super.key, required this.tools});
  final List<(IconData, String, VoidCallback)> tools;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      color: Ed.bar,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        itemCount: tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 26),
        itemBuilder: (_, i) {
          final (icon, label, onTap) = tools[i];
          return _ToolButton(icon: icon, label: label, onTap: onTap);
        },
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Ed.icon, size: 24),
        const SizedBox(height: 6),
        Text(label, style: Ed.label),
      ]),
    );
  }
}

/// Gap (px) between the top edge of the selection box and the rotation handle.
const double _kRotGap = 24;

/// Draws the selection box + corner scale handles + rotation handle for the
/// selected on-canvas element, rotated with it. Purely visual — hit-testing and
/// gestures live on the canvas-spanning layer in _EditorScreenState.
class _GizmoPainter extends CustomPainter {
  _GizmoPainter({required this.center, required this.boxSize, required this.rotationDeg});
  final Offset center;
  final Size boxSize;
  final double rotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationDeg * math.pi / 180);
    final hw = boxSize.width / 2, hh = boxSize.height / 2;
    final line = Paint()
      ..color = Ed.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh, hw, hh), const Radius.circular(3)),
      line,
    );
    // Rotation stub + handle above top-centre.
    canvas.drawLine(Offset(0, -hh), Offset(0, -hh - _kRotGap), line);
    final fill = Paint()..color = Colors.white;
    final edge = Paint()
      ..color = Ed.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void dot(Offset o) {
      canvas.drawCircle(o, 6, fill);
      canvas.drawCircle(o, 6, edge);
    }

    dot(Offset(-hw, -hh));
    dot(Offset(hw, -hh));
    dot(Offset(-hw, hh));
    dot(Offset(hw, hh));
    dot(Offset(0, -hh - _kRotGap)); // rotation handle
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GizmoPainter old) =>
      old.center != center || old.boxSize != boxSize || old.rotationDeg != rotationDeg;
}
