import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_job.dart';
import '../data/remote/ai_pipeline_service.dart';
import 'app_providers.dart';

/// Live state of an AI processing run, consumed by the AI Processing screen.
class AiJobState {
  const AiJobState({
    required this.statuses,
    required this.running,
    required this.complete,
    this.result,
  });

  final List<StageStatus> statuses;
  final bool running;
  final bool complete;
  final PipelineResult? result;

  factory AiJobState.initial() => AiJobState(
        statuses: List.filled(kPipelineStages.length, StageStatus.pending),
        running: false,
        complete: false,
      );

  int get doneCount => statuses.where((s) => s == StageStatus.done).length;
  double get progress => statuses.isEmpty ? 0 : doneCount / statuses.length;

  AiJobState copyWith({
    List<StageStatus>? statuses,
    bool? running,
    bool? complete,
    PipelineResult? result,
  }) {
    return AiJobState(
      statuses: statuses ?? this.statuses,
      running: running ?? this.running,
      complete: complete ?? this.complete,
      result: result ?? this.result,
    );
  }
}

class AiJobNotifier extends StateNotifier<AiJobState> {
  AiJobNotifier(this._service) : super(AiJobState.initial());

  final AiPipelineService _service;

  void reset() => state = AiJobState.initial();

  Future<PipelineResult> start({required File video, required int fallbackDurationMs}) async {
    state = AiJobState.initial().copyWith(running: true);

    final result = await _service.run(
      video: video,
      fallbackDurationMs: fallbackDurationMs,
      onStage: (index, status) {
        final next = [...state.statuses];
        next[index] = status;
        state = state.copyWith(statuses: next);
      },
    );

    state = state.copyWith(running: false, complete: true, result: result);
    return result;
  }
}

final aiJobProvider = StateNotifierProvider<AiJobNotifier, AiJobState>(
  (ref) => AiJobNotifier(ref.watch(aiPipelineServiceProvider)),
);
