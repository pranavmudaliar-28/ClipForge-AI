import 'package:flutter/material.dart';

/// The AI processing pipeline stages shown on the AI Processing screen.
///
/// All stages animate as timed progress EXCEPT the one marked [isReal], which
/// calls the backend `/transcribe` endpoint and blocks on the actual result.

enum StageStatus { pending, running, done }

@immutable
class PipelineStage {
  const PipelineStage(this.key, this.label, this.icon, {this.isReal = false});

  final String key;
  final String label;
  final IconData icon;
  final bool isReal;
}

const List<PipelineStage> kPipelineStages = [
  PipelineStage('proxy', 'Generating preview proxy', Icons.movie_filter_outlined),
  PipelineStage('audio', 'Extracting audio track', Icons.graphic_eq),
  PipelineStage('transcribe', 'Transcribing speech', Icons.record_voice_over_outlined, isReal: true),
  PipelineStage('vad', 'Detecting & trimming silence', Icons.content_cut),
  PipelineStage('scene', 'Scene detection', Icons.auto_awesome_motion_outlined),
  PipelineStage('face', 'Face & subject tracking', Icons.center_focus_strong_outlined),
  PipelineStage('object', 'Object detection', Icons.category_outlined),
  PipelineStage('beats', 'Analyzing music beats', Icons.music_note_outlined),
  PipelineStage('highlights', 'Finding best moments', Icons.bolt_outlined),
  PipelineStage('captions', 'Styling captions', Icons.subtitles_outlined),
  PipelineStage('timeline', 'Composing timeline', Icons.dashboard_customize_outlined),
];
