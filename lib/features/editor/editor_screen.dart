import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/canvas_preset.dart';
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

  // On-canvas text drag/pinch state (captured at gesture start).
  Offset _txtStartFocal = Offset.zero;
  double _txtStartX = 0.5, _txtStartY = 0.5, _txtStartSize = 34;
  bool _txtMoved = false;

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
  int _sourceToOutput(int srcMs, List<Clip> clips) {
    var cursor = 0;
    for (final c in clips) {
      if (srcMs >= c.startMs && srcMs <= c.endMs) {
        return cursor + ((srcMs - c.startMs) / c.speed).round();
      }
      cursor += c.playbackMs;
    }
    return cursor;
  }

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

  void _onTick() {
    final v = _video;
    if (v == null || !v.value.isInitialized || _seeking) return;
    if (v.value.isPlaying) {
      final clips = ref.read(editorControllerProvider(widget.projectId)).timeline.clips;
      _ctrl.seek(_sourceToOutput(v.value.position.inMilliseconds, clips));
    }
  }

  Future<void> _seekToOutput(int outMs) async {
    final v = _video;
    if (v == null) return;
    final clips = ref.read(editorControllerProvider(widget.projectId)).timeline.clips;
    _seeking = true;
    _ctrl.seek(outMs);
    await v.seekTo(Duration(milliseconds: _outputToSource(outMs, clips)));
    _seeking = false;
  }

  void _togglePlay() {
    final v = _video;
    if (v == null) return;
    HapticFeedback.selectionClick();
    v.value.isPlaying ? v.pause() : v.play();
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
            _Toolbar(tools: _tools(state)),
          ]),
        ),
      ),
    );
  }

  double _selectedSpeed(EditorState s) {
    for (final c in s.timeline.clips) {
      if (c.id == s.selectedClipId) return c.speed;
    }
    return 1.0;
  }

  List<(IconData, String, VoidCallback)> _tools(EditorState state) => [
        (Icons.crop_free_rounded, 'Canvas', () => showCanvasSheet(context, state.canvasId, _ctrl.setCanvas)),
        (Icons.content_cut_rounded, 'Split', () {
          _ctrl.splitAtPlayhead();
          HapticFeedback.mediumImpact();
        }),
        (Icons.speed_rounded, 'Speed', () => showSpeedSheet(context, _selectedSpeed(state), _ctrl.setSpeed)),
        (Icons.auto_awesome_rounded, 'Filter', () => showFilterSheet(context, _ctrl)),
        (Icons.tune_rounded, 'Adjust', () => showAdjustSheet(context, _ctrl)),
        (Icons.blur_on_rounded, 'Effects', () => showEffectsSheet(context, _ctrl)),
        (Icons.text_fields_rounded, 'Text', () => showTextSheet(context, _ctrl)),
        (Icons.subtitles_outlined, 'Captions', () => showCaptionsSheet(context, _ctrl)),
        (Icons.volume_up_outlined, 'Volume', () => showAudioSheet(context, _ctrl)),
        (Icons.swap_horiz_rounded, 'Transition', () => showTransitionSheet(context, _ctrl)),
        (Icons.blur_circular_outlined, 'Cutout', () => showCutoutSheet(context, _ctrl)),
        (Icons.copy_rounded, 'Duplicate', _ctrl.duplicateSelected),
        (Icons.delete_outline_rounded, 'Delete', _ctrl.deleteSelected),
        (Icons.auto_fix_high_rounded, 'AI Tools', _openAiTools),
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
            imageFilter: ImageFilter.blur(sigmaX: s.previewBlurSigma, sigmaY: s.previewBlurSigma),
            child: v,
          );
        }
        content = v;
      } else if (_failed) {
        content = const Center(child: Text('Preview unavailable', style: TextStyle(color: Ed.muted)));
      } else {
        content = const Center(child: CircularProgressIndicator(color: Ed.accent));
      }

      final textScale = box.maxHeight / (canvas.exportH == 0 ? 1920 : canvas.exportH);
      return GestureDetector(
        onTap: _togglePlay,
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
          for (final t in s.texts)
            Align(
              alignment: Alignment(t.xNorm * 2 - 1, t.yNorm * 2 - 1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // Tap to edit this text in place (pre-filled sheet).
                onTap: () => showTextSheet(context, _ctrl, editing: t),
                // Drag to move, pinch to resize — live during gesture, one undo
                // step committed on release (mirrors the slider record:false/true
                // pattern in editor_provider).
                onScaleStart: (d) {
                  _txtStartFocal = d.focalPoint;
                  _txtStartX = t.xNorm;
                  _txtStartY = t.yNorm;
                  _txtStartSize = t.sizePt;
                  _txtMoved = false;
                },
                onScaleUpdate: (d) {
                  final dxN = (d.focalPoint.dx - _txtStartFocal.dx) / box.maxWidth;
                  final dyN = (d.focalPoint.dy - _txtStartFocal.dy) / box.maxHeight;
                  if (d.scale != 1.0 || dxN.abs() > 0.005 || dyN.abs() > 0.005) _txtMoved = true;
                  final nx = (_txtStartX + dxN).clamp(0.02, 0.98);
                  final ny = (_txtStartY + dyN).clamp(0.02, 0.98);
                  final nSize = (_txtStartSize * d.scale).clamp(12.0, 160.0);
                  _ctrl.updateText(t.copyWith(xNorm: nx, yNorm: ny, sizePt: nSize), record: false);
                },
                onScaleEnd: (_) {
                  if (!_txtMoved) return;
                  final cur = _ctrl.settings.texts.firstWhere((x) => x.id == t.id, orElse: () => t);
                  _ctrl.updateText(cur);
                },
                child: Text(
                  t.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(int.parse('FF${t.colorHex.substring(1)}', radix: 16)),
                    fontSize: (t.sizePt * textScale).clamp(8, 200),
                    fontWeight: FontWeight.w800,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
            ),
          if (_video != null) _captionOverlay(state),
          if (_video != null && !_video!.value.isPlaying)
            Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ),
        ]),
      );
    });
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
                onSeek: _seekToOutput,
                onSelectClip: _ctrl.select,
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
  const _Toolbar({required this.tools});
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
