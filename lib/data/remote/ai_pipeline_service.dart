import 'dart:io';

import '../models/ai_job.dart';
import '../models/timeline.dart';
import '../models/transcript.dart';
import 'transcription_service.dart';

class PipelineResult {
  const PipelineResult({
    required this.transcript,
    required this.timeline,
    required this.usedRealTranscript,
    this.error,
  });

  final Transcript transcript;
  final Timeline timeline;
  final bool usedRealTranscript;
  final String? error;
}

/// Orchestrates the AI processing pipeline.
///
/// Every stage animates as timed progress except the one flagged
/// [PipelineStage.isReal], which calls the backend for a real transcript. If
/// the backend is unreachable the pipeline degrades gracefully (empty
/// transcript) so the app remains usable offline, recording [error].
class AiPipelineService {
  AiPipelineService(this._transcription);

  final TranscriptionService _transcription;

  // Simulated durations (ms) for the mocked stages, keyed by stage key.
  static const Map<String, int> _simulatedMs = {
    'proxy': 900,
    'audio': 700,
    'vad': 600,
    'scene': 800,
    'face': 900,
    'object': 700,
    'beats': 600,
    'highlights': 900,
    'captions': 700,
    'timeline': 600,
  };

  Future<PipelineResult> run({
    required File video,
    required int fallbackDurationMs,
    required void Function(int stageIndex, StageStatus status) onStage,
  }) async {
    var transcript = Transcript.empty;
    var usedReal = false;
    String? error;

    for (var i = 0; i < kPipelineStages.length; i++) {
      final stage = kPipelineStages[i];
      onStage(i, StageStatus.running);

      if (stage.isReal) {
        try {
          transcript = await _transcription.transcribe(video);
          usedReal = true;
        } catch (e) {
          error = 'Transcription unavailable — is the backend running? ($e)';
          transcript = Transcript.empty;
        }
      } else {
        await Future<void>.delayed(Duration(milliseconds: _simulatedMs[stage.key] ?? 700));
      }

      onStage(i, StageStatus.done);
    }

    final timeline = Timeline.fromTranscript(transcript, fallbackDurationMs: fallbackDurationMs);
    return PipelineResult(
      transcript: transcript,
      timeline: timeline,
      usedRealTranscript: usedReal,
      error: error,
    );
  }
}
