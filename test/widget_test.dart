import 'dart:io';

import 'package:clipforge_ai/core/render/ffmpeg_composer.dart';
import 'package:clipforge_ai/core/utils/formatters.dart';
import 'package:clipforge_ai/data/models/canvas_preset.dart';
import 'package:clipforge_ai/data/models/edit_settings.dart';
import 'package:clipforge_ai/data/models/timeline.dart';
import 'package:clipforge_ai/data/models/transcript.dart';
import 'package:clipforge_ai/providers/editor_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters', () {
    test('duration formats mm:ss and h:mm:ss', () {
      expect(Formatters.duration(0), '0:00');
      expect(Formatters.duration(123456), '2:03');
      expect(Formatters.duration(3723000), '1:02:03');
    });

    test('fileSize is human readable', () {
      expect(Formatters.fileSize(0), '—');
      expect(Formatters.fileSize(2048), '2.0 KB');
      expect(Formatters.fileSize(15 * 1024 * 1024), '15 MB');
    });
  });

  group('Timeline', () {
    test('builds captions from a transcript', () {
      const transcript = Transcript(
        language: 'en',
        duration: 4,
        text: 'hello world',
        segments: [
          TranscriptSegment(id: 0, start: 0, end: 2, text: 'hello'),
          TranscriptSegment(id: 1, start: 2, end: 4, text: 'world'),
        ],
      );
      final timeline = Timeline.fromTranscript(transcript, fallbackDurationMs: 1000);
      expect(timeline.durationMs, 4000);
      expect(timeline.captions.length, 2);
      expect(timeline.captions.first.text, 'hello');
      expect(timeline.clips.length, 2);
    });

    test('round-trips through JSON', () {
      final original = Timeline.fromTranscript(
        const Transcript(
          language: 'en',
          duration: 3,
          text: 'hi',
          segments: [TranscriptSegment(id: 0, start: 0, end: 3, text: 'hi')],
        ),
        fallbackDurationMs: 3000,
      );
      final restored = Timeline.fromJson(original.toJson());
      expect(restored.durationMs, original.durationMs);
      expect(restored.captions.length, original.captions.length);
      expect(restored.audio.length, original.audio.length);
    });
  });

  group('TextOverlay', () {
    test('round-trips timing + transform fields through JSON', () {
      const t = TextOverlay(
        id: 'x',
        text: 'hi',
        xNorm: 0.4,
        yNorm: 0.7,
        sizePt: 40,
        colorHex: '#08D0F2',
        startMs: 1200,
        endMs: 4200,
        rotationDeg: 15,
        opacity: 0.5,
      );
      final r = TextOverlay.fromJson(t.toJson());
      expect(r.startMs, 1200);
      expect(r.endMs, 4200);
      expect(r.rotationDeg, 15);
      expect(r.opacity, 0.5);
      expect(r.xNorm, 0.4);
      expect(r.colorHex, '#08D0F2');
    });

    test('old JSON without new keys defaults to full-duration/no-rotation/opaque', () {
      final r = TextOverlay.fromJson(const {
        'id': 't',
        'text': 'legacy',
        'xNorm': 0.5,
        'yNorm': 0.5,
        'sizePt': 34,
        'colorHex': '#FFFFFF',
      });
      expect(r.startMs, 0);
      expect(r.endMs, 0);
      expect(r.rotationDeg, 0);
      expect(r.opacity, 1);
      expect(r.effectiveEndMs(5000), 5000); // open-ended ⇒ full duration
    });

    test('effectiveEndMs honours an explicit window', () {
      const t = TextOverlay(id: 'a', text: 'b', startMs: 1000, endMs: 3000);
      expect(t.effectiveEndMs(10000), 3000);
    });
  });

  group('Selection', () {
    test('equality by kind + id; none is empty', () {
      expect(const Selection(SelectionKind.text, 't1'), const Selection(SelectionKind.text, 't1'));
      expect(const Selection(SelectionKind.text, 't1') == const Selection(SelectionKind.clip, 't1'), false);
      expect(Selection.none.isNone, true);
      expect(const Selection(SelectionKind.clip, 'c').isNone, false);
    });
  });

  group('FfmpegComposer text', () {
    test('burns each text within its own window with rotation + alpha', () async {
      final dir = await Directory.systemTemp.createTemp('cf_ass_test');
      final assPath = '${dir.path}/subs.ass';
      const timeline = Timeline(
        durationMs: 5000,
        clips: [Clip(id: 'c0', startMs: 0, endMs: 5000)],
        captions: [],
        effects: [],
        audio: [],
        settings: EditSettings(texts: [
          TextOverlay(id: 't', text: 'Hi', startMs: 1000, endMs: 3000, rotationDeg: 10, opacity: 0.5),
        ]),
      );
      final job = await FfmpegComposer.build(
        sourcePath: '/tmp/in.mp4',
        timeline: timeline,
        canvas: CanvasPreset.all.first,
        exportW: 1080,
        exportH: 1920,
        outputPath: '${dir.path}/out.mp4',
        subtitlePath: assPath,
        watermark: false,
      );
      final ass = await File(assPath).readAsString();
      expect(ass.contains('Dialogue: 0,0:00:01.00,0:00:03.00,Txt'), true);
      expect(ass.contains('\\frz-10.00'), true); // negated to match preview
      expect(ass.contains('\\alpha&H80&'), true); // 50% opacity
      expect(job.command.contains('subtitles='), true);
      await dir.delete(recursive: true);
    });

    test('emits per-clip flip/rotate + volume/fade filters', () async {
      final dir = await Directory.systemTemp.createTemp('cf_clip_test');
      const timeline = Timeline(
        durationMs: 4000,
        clips: [
          Clip(id: 'c0', startMs: 0, endMs: 4000, volume: 0.5, fadeInMs: 500, fadeOutMs: 500, flipH: true, quarterTurns: 1),
        ],
        captions: [],
        effects: [],
        audio: [],
      );
      final job = await FfmpegComposer.build(
        sourcePath: '/tmp/in.mp4',
        timeline: timeline,
        canvas: CanvasPreset.all.first,
        exportW: 1080,
        exportH: 1920,
        outputPath: '${dir.path}/out.mp4',
        subtitlePath: '${dir.path}/s.ass',
        watermark: false,
      );
      expect(job.command.contains('transpose=1'), true); // 90° rotation
      expect(job.command.contains('hflip'), true);
      expect(job.command.contains('volume=0.50'), true);
      expect(job.command.contains('fade=t=in'), true); // video fade
      expect(job.command.contains('afade=t=out'), true); // audio fade
      await dir.delete(recursive: true);
    });
  });

  group('Clip per-clip props', () {
    test('round-trips new fields through JSON', () {
      const c = Clip(
        id: 'c',
        startMs: 0,
        endMs: 1000,
        volume: 0.5,
        fadeInMs: 300,
        fadeOutMs: 400,
        flipH: true,
        flipV: false,
        quarterTurns: 3,
      );
      final r = Clip.fromJson(c.toJson());
      expect(r.volume, 0.5);
      expect(r.fadeInMs, 300);
      expect(r.fadeOutMs, 400);
      expect(r.flipH, true);
      expect(r.flipV, false);
      expect(r.quarterTurns, 3);
    });

    test('old JSON without new keys defaults to identity transform', () {
      final r = Clip.fromJson(const {'id': 'c', 'startMs': 0, 'endMs': 1000});
      expect(r.volume, 1.0);
      expect(r.fadeInMs, 0);
      expect(r.fadeOutMs, 0);
      expect(r.flipH, false);
      expect(r.flipV, false);
      expect(r.quarterTurns, 0);
    });

    test('copyWith can change track (needed for later multi-track batches)', () {
      const c = Clip(id: 'c', startMs: 0, endMs: 1000);
      expect(c.copyWith(track: 2).track, 2);
      expect(c.copyWith().track, 0);
    });
  });
}
