import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/design/app_dimens.dart';
import '../../core/design/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/ai_job.dart';
import '../../data/models/project.dart';
import '../../providers/ai_job_provider.dart';
import '../../providers/projects_provider.dart';

class AiProcessingScreen extends ConsumerStatefulWidget {
  const AiProcessingScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<AiProcessingScreen> createState() => _AiProcessingScreenState();
}

class _AiProcessingScreenState extends ConsumerState<AiProcessingScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<int> _probeDurationMs(File video) async {
    try {
      final controller = VideoPlayerController.file(video);
      await controller.initialize();
      final ms = controller.value.duration.inMilliseconds;
      await controller.dispose();
      return ms > 0 ? ms : 15000;
    } catch (_) {
      return 15000;
    }
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;

    final project = ref.read(projectsProvider.notifier).byId(widget.projectId);
    if (project == null || project.sourcePath == null) {
      if (mounted) context.go(AppRoutes.home);
      return;
    }
    final video = File(project.sourcePath!);
    final fallbackMs = await _probeDurationMs(video);
    final result =
        await ref.read(aiJobProvider.notifier).start(video: video, fallbackDurationMs: fallbackMs);

    await ref.read(projectsProvider.notifier).upsert(project.copyWith(
          transcript: result.transcript,
          timeline: result.timeline,
          durationMs: result.timeline.durationMs,
          status: ProjectStatus.ready,
        ));

    if (!mounted) return;
    if (result.error != null) {
      showAppToast(context, 'Backend offline — simulated the transcript stage.', type: ToastType.info);
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted) context.pushReplacement(AppRoutes.wizardFor(widget.projectId));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final job = ref.watch(aiJobProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.screen),
          child: Column(
            children: [
              Gap.h20,
              _Ring(progress: job.progress),
              Gap.h20,
              Text('AI is editing your video', style: context.text.titleLarge),
              Gap.h4,
              Text('Analyzing footage, speech, and audio…',
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
              Gap.h24,
              Expanded(
                child: ListView.builder(
                  itemCount: kPipelineStages.length,
                  itemBuilder: (_, i) => _StageRow(stage: kPipelineStages[i], status: job.statuses[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 8,
                backgroundColor: c.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(c.primary),
              ),
            ),
          ),
          Text('${(progress * 100).round()}%', style: context.text.headlineSmall),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.status});
  final PipelineStage stage;
  final StageStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = status == StageStatus.done;
    final running = status == StageStatus.running;
    final active = done || running;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: active ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(
            width: 28,
            height: 28,
            child: done
                ? Icon(Icons.check_circle_rounded, color: c.success, size: 24)
                : running
                    ? const CircularProgressIndicator(strokeWidth: 2.4)
                    : Icon(stage.icon, color: c.textTertiary, size: 22),
          ),
          Gap.w12,
          Expanded(
            child: Text(stage.label,
                style: context.text.bodyLarge?.copyWith(
                  color: active ? c.textPrimary : c.textSecondary,
                  fontWeight: running ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
          if (stage.isReal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(gradient: c.brandGradient, borderRadius: BorderRadius.circular(Radii.pill)),
              child: const Text('LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}
