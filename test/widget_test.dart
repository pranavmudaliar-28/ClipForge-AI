import 'package:clipforge_ai/core/utils/formatters.dart';
import 'package:clipforge_ai/data/models/timeline.dart';
import 'package:clipforge_ai/data/models/transcript.dart';
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
}
