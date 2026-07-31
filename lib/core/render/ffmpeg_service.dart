import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

/// Thin async wrapper around ffmpeg_kit. Runs a command with real progress
/// (derived from processed media time) and resolves to success/failure.
class FfmpegService {
  /// Runs [command]; [onProgress] receives 0..1 based on processed time vs
  /// [totalMs]. Returns true on a zero return code AND a non-empty output file.
  Future<bool> run(
    String command, {
    required int totalMs,
    String? outputPath,
    void Function(double progress)? onProgress,
    void Function(String line)? onLog,
  }) async {
    final completer = Completer<bool>();
    await FFmpegKit.executeAsync(
      command,
      (FFmpegSession session) async {
        final rc = await session.getReturnCode();
        var ok = ReturnCode.isSuccess(rc);
        if (ok && outputPath != null) {
          final f = File(outputPath);
          ok = f.existsSync() && await f.length() > 0; // verify real output
        }
        if (!completer.isCompleted) completer.complete(ok);
      },
      (log) => onLog?.call(log.getMessage()),
      (Statistics s) {
        if (totalMs > 0 && onProgress != null) {
          onProgress((s.getTime() / totalMs).clamp(0.0, 1.0));
        }
      },
    );
    return completer.future;
  }

  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }

  /// Returns true if [source] has at least one audio stream. Reads just the
  /// container header (processes 0.1s), so it's fast. Used before adding a clip
  /// so the composer can synthesize silence for sources with no audio track
  /// (otherwise concat, which needs audio on every segment, would fail).
  Future<bool> hasAudioStream(String source) async {
    var found = false;
    final re = RegExp(r'Stream #\d+:\d+.*: Audio:');
    await run(
      "-hide_banner -i '$source' -t 0.1 -f null -",
      totalMs: 0,
      onLog: (line) {
        if (re.hasMatch(line)) found = true;
      },
    );
    return found;
  }

  /// Extracts a single frame at [atMs] to [outPath] (used for thumbnails).
  Future<bool> extractFrame(String source, int atMs, String outPath) async {
    final t = (atMs / 1000).toStringAsFixed(2);
    final cmd = "-y -ss $t -i '$source' -frames:v 1 -q:v 3 '$outPath'";
    return run(cmd, totalMs: 0, outputPath: outPath);
  }
}
