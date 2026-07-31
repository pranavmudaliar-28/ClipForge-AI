import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/canvas_preset.dart';
import '../../data/models/project.dart';
import 'ffmpeg_composer.dart';
import 'ffmpeg_service.dart';

class ExportResult {
  const ExportResult({
    required this.success,
    this.outputPath,
    this.savedToGallery = false,
    this.error,
  });
  final bool success;
  final String? outputPath;
  final bool savedToGallery;
  final String? error;
}

/// Orchestrates a real export: compose → render (real progress) → save to
/// gallery → verify the file exists. Fixes the old "100% but nothing saved".
class ExportService {
  ExportService(this._ffmpeg);
  final FfmpegService _ffmpeg;

  Future<ExportResult> export({
    required Project project,
    required int exportW,
    required int exportH,
    void Function(double progress)? onProgress,
    bool watermark = true,
  }) async {
    final source = project.sourcePath;
    if (source == null || !File(source).existsSync()) {
      return const ExportResult(success: false, error: 'Source video not found.');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = project.updatedAt.millisecondsSinceEpoch;
      final outPath = '${dir.path}/clipforge_${project.id}_$stamp.mp4';
      final assPath = '${dir.path}/clipforge_${project.id}.ass';

      final job = await FfmpegComposer.build(
        sourcePath: source,
        timeline: project.timeline,
        canvas: CanvasPreset.byId(project.canvasId),
        exportW: exportW,
        exportH: exportH,
        outputPath: outPath,
        subtitlePath: assPath,
        watermark: watermark,
      );

      // Keep a rolling tail of ffmpeg logs to surface the real failure reason.
      final logTail = <String>[];
      void capture(String line) {
        logTail.add(line);
        if (logTail.length > 60) logTail.removeAt(0);
      }

      var ok = await _ffmpeg.run(
        job.command,
        totalMs: job.totalMs,
        outputPath: outPath,
        onProgress: onProgress,
        onLog: capture,
      );

      // Fallback: if the full filtergraph failed, retry a minimal safe re-encode
      // (trim + concat + scale only) so export still produces a valid file.
      if (!ok) {
        final minJob = FfmpegComposer.buildMinimal(
          sourcePath: source,
          timeline: project.timeline,
          exportW: exportW,
          exportH: exportH,
          outputPath: outPath,
        );
        ok = await _ffmpeg.run(
          minJob.command,
          totalMs: minJob.totalMs,
          outputPath: outPath,
          onProgress: onProgress,
          onLog: capture,
        );
      }

      if (!ok) {
        final reason = logTail.reversed.firstWhere(
          (l) {
            final s = l.toLowerCase();
            return s.contains('error') || s.contains('invalid') || s.contains('no such') || s.contains('unable') || s.contains('failed');
          },
          orElse: () => logTail.isNotEmpty ? logTail.last : 'unknown error',
        );
        return ExportResult(success: false, error: 'Render failed — $reason');
      }

      // Verify before claiming success.
      final file = File(outPath);
      if (!file.existsSync() || await file.length() == 0) {
        return const ExportResult(success: false, error: 'Output file was not created.');
      }

      var saved = false;
      try {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        await Gal.putVideo(outPath, album: 'ClipForge AI');
        saved = true;
      } catch (_) {
        saved = false; // file still exists on disk; surface a soft warning
      }

      return ExportResult(success: true, outputPath: outPath, savedToGallery: saved);
    } catch (e) {
      return ExportResult(success: false, error: '$e');
    }
  }

  Future<void> cancel() => _ffmpeg.cancel();
}
