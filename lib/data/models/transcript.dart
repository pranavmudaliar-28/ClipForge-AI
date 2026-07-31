/// Speech-to-text result returned by the backend `/transcribe` endpoint.
///
/// Field names mirror `backend/app/schemas.py` — keep the two in sync.
class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });

  final int id;
  final double start; // seconds
  final double end; // seconds
  final String text;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) => TranscriptSegment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        start: (json['start'] as num?)?.toDouble() ?? 0,
        end: (json['end'] as num?)?.toDouble() ?? 0,
        text: (json['text'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'start': start, 'end': end, 'text': text};
}

class Transcript {
  const Transcript({
    required this.language,
    required this.duration,
    required this.text,
    required this.segments,
  });

  final String language;
  final double duration; // seconds
  final String text;
  final List<TranscriptSegment> segments;

  bool get isEmpty => segments.isEmpty;

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
        language: json['language'] as String? ?? 'en',
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        text: json['text'] as String? ?? '',
        segments: ((json['segments'] as List?) ?? const [])
            .map((e) => TranscriptSegment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'duration': duration,
        'text': text,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  static const empty = Transcript(language: 'en', duration: 0, text: '', segments: []);
}
