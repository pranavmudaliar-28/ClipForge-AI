import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/render/export_service.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/canvas_preset.dart';
import '../../providers/app_providers.dart';
import '../../providers/projects_provider.dart';

enum _Phase { config, rendering, done, error }

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _Phase _phase = _Phase.config;
  int _tier = 1080; // short-edge target
  double _progress = 0;
  DateTime? _start;
  ExportResult? _result;

  static const _tiers = [720, 1080, 1440, 2160];
  String _tierLabel(int t) => switch (t) { 720 => '720p', 1080 => '1080p', 1440 => '2K', _ => '4K' };

  (int, int) _dims(CanvasPreset canvas) {
    int even(int n) => n.isEven ? n : n + 1;
    if (canvas.ratio < 1) {
      return (even(_tier), even((_tier / canvas.ratio).round()));
    }
    return (even((_tier * canvas.ratio).round()), even(_tier));
  }

  Future<void> _startRender() async {
    final project = ref.read(projectsProvider.notifier).byId(widget.projectId);
    if (project == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.rendering;
      _progress = 0;
      _start = DateTime.now();
    });

    final (w, h) = _dims(CanvasPreset.byId(project.canvasId));
    final result = await ref.read(exportServiceProvider).export(
          project: project,
          exportW: w,
          exportH: h,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );

    if (!mounted) return;
    if (result.success) {
      await ref.read(projectsProvider.notifier).upsert(project.copyWith(exportPath: result.outputPath));
      HapticFeedback.mediumImpact();
      setState(() {
        _result = result;
        _phase = _Phase.done;
      });
    } else {
      setState(() {
        _result = result;
        _phase = _Phase.error;
      });
    }
  }

  String get _eta {
    if (_start == null || _progress < 0.02) return 'Estimating…';
    final elapsed = DateTime.now().difference(_start!).inSeconds;
    final total = elapsed / _progress;
    final remain = (total - elapsed).clamp(0, 3600).round();
    return remain < 60 ? '${remain}s left' : '${(remain / 60).ceil()}m left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.config => _config(),
          _Phase.rendering => _rendering(),
          _Phase.done => _done(),
          _Phase.error => _error(),
        },
      ),
    );
  }

  Widget _config() {
    final c = context.colors;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(Gap.screen),
          children: [
            Text('Resolution', style: context.text.titleMedium),
            Gap.h12,
            ..._tiers.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: _resTile(t),
                )),
            Gap.h8,
            AppCard(
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: c.accent),
                Gap.w12,
                Expanded(
                  child: Text('Free exports include a ClipForge watermark. Upgrade to Pro to remove it.',
                      style: context.text.bodySmall?.copyWith(color: c.textSecondary)),
                ),
              ]),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(Gap.screen),
        child: AppButton(label: 'Export ${_tierLabel(_tier)}', icon: Icons.movie_filter_rounded, onPressed: _startRender),
      ),
    ]);
  }

  Widget _resTile(int t) {
    final c = context.colors;
    final selected = _tier == t;
    return GestureDetector(
      onTap: () => setState(() => _tier = t),
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: selected ? c.primary : c.border, width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(Icons.high_quality_rounded, color: selected ? c.primary : c.textSecondary),
          Gap.w12,
          Expanded(child: Text(_tierLabel(t), style: context.text.titleSmall)),
          if (selected) Icon(Icons.check_circle_rounded, color: c.primary),
        ]),
      ),
    );
  }

  Widget _rendering() {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 128,
            height: 128,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 128,
                height: 128,
                child: CircularProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  strokeWidth: 8,
                  backgroundColor: c.surfaceHigh,
                  valueColor: AlwaysStoppedAnimation(c.primary),
                ),
              ),
              Text('${(_progress * 100).round()}%', style: context.text.headlineSmall),
            ]),
          ),
          Gap.h24,
          Text('Rendering your video…', style: context.text.titleMedium),
          Gap.h4,
          Text(_eta, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
          Gap.h24,
          TextButton(
            onPressed: () async {
              await ref.read(exportServiceProvider).cancel();
              if (mounted) setState(() => _phase = _Phase.config);
            },
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
        ]),
      ),
    );
  }

  Widget _done() {
    final c = context.colors;
    final saved = _result?.savedToGallery ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.screen),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(gradient: c.brandGradient, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ),
          Gap.h20,
          Text('Export complete!', style: context.text.headlineSmall),
          Gap.h8,
          Text(saved ? 'Saved to your gallery · album “ClipForge AI”.' : 'Rendered to app storage.',
              textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
          Gap.h24,
          AppButton(
            label: 'Share',
            icon: Icons.ios_share_rounded,
            onPressed: () {
              final p = _result?.outputPath;
              if (p != null) SharePlus.instance.share(ShareParams(files: [XFile(p)]));
            },
          ),
          Gap.h12,
          AppButton.ghost(label: 'Back to home', expand: true, onPressed: () => context.go(AppRoutes.home)),
        ]),
      ),
    );
  }

  Widget _error() {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.screen),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: c.error, size: 64),
          Gap.h16,
          Text('Export failed', style: context.text.titleLarge),
          Gap.h8,
          Text(_result?.error ?? 'Something went wrong.',
              textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
          Gap.h24,
          AppButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: _startRender),
          Gap.h12,
          AppButton.ghost(label: 'Back', expand: true, onPressed: () => setState(() => _phase = _Phase.config)),
        ]),
      ),
    );
  }
}
