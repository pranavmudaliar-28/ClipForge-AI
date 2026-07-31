import 'edit_settings.dart';
import 'transcript.dart';

/// The editable timeline — the JSON document the AI pipeline produces and the
/// editor renders. Captions come from the real transcript; other layers are
/// mock-generated in Phase 1 (see [Timeline.fromTranscript]).

/// A segment of the source video placed on the video track. [startMs]/[endMs]
/// are the **source in/out** points; segments play back-to-back in list order.
class Clip {
  const Clip({
    required this.id,
    required this.startMs,
    required this.endMs,
    this.label = 'Clip',
    this.track = 0,
    this.speed = 1.0,
    this.sourcePath,
    this.hasAudio = true,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String label;
  final int track;
  final double speed; // 0.25–4.0

  /// The media file this clip is cut from. `null` means it uses the project's
  /// original source video (backward-compatible with pre-multi-source projects);
  /// a non-null path lets distinct source files coexist on the same timeline.
  final String? sourcePath;

  /// Whether the clip's source has an audio stream. Defaults to true (the
  /// project source always has audio). Added clips probe this so the composer
  /// can synthesize silence for muted sources instead of failing concat.
  final bool hasAudio;

  int get durationMs => (endMs - startMs).clamp(0, 1 << 31);

  /// Duration on the timeline after the speed factor is applied.
  int get playbackMs => (durationMs / speed).round();

  Clip copyWith({int? startMs, int? endMs, String? label, double? speed, String? sourcePath, bool? hasAudio}) => Clip(
        id: id,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        label: label ?? this.label,
        track: track,
        speed: speed ?? this.speed,
        sourcePath: sourcePath ?? this.sourcePath,
        hasAudio: hasAudio ?? this.hasAudio,
      );

  factory Clip.fromJson(Map<String, dynamic> j) => Clip(
        id: j['id'] as String? ?? '',
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? 'Clip',
        track: (j['track'] as num?)?.toInt() ?? 0,
        speed: (j['speed'] as num?)?.toDouble() ?? 1.0,
        sourcePath: j['sourcePath'] as String?,
        hasAudio: j['hasAudio'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startMs': startMs,
        'endMs': endMs,
        'label': label,
        'track': track,
        'speed': speed,
        'sourcePath': sourcePath,
        'hasAudio': hasAudio,
      };
}

class CaptionCue {
  const CaptionCue({required this.id, required this.startMs, required this.endMs, required this.text});

  final String id;
  final int startMs;
  final int endMs;
  final String text;

  factory CaptionCue.fromJson(Map<String, dynamic> j) => CaptionCue(
        id: j['id'] as String? ?? '',
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        text: j['text'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'startMs': startMs, 'endMs': endMs, 'text': text};
}

enum EffectKind { zoom, transition, colorGrade, bRoll }

class EffectLayer {
  const EffectLayer({
    required this.id,
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.label,
  });

  final String id;
  final EffectKind kind;
  final int startMs;
  final int endMs;
  final String label;

  factory EffectLayer.fromJson(Map<String, dynamic> j) => EffectLayer(
        id: j['id'] as String? ?? '',
        kind: EffectKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => EffectKind.zoom),
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind.name, 'startMs': startMs, 'endMs': endMs, 'label': label};
}

enum AudioKind { music, voice, sfx }

class AudioLayer {
  const AudioLayer({
    required this.id,
    required this.kind,
    required this.startMs,
    required this.endMs,
    required this.label,
    this.gain = 1.0,
  });

  final String id;
  final AudioKind kind;
  final int startMs;
  final int endMs;
  final String label;
  final double gain;

  factory AudioLayer.fromJson(Map<String, dynamic> j) => AudioLayer(
        id: j['id'] as String? ?? '',
        kind: AudioKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => AudioKind.music),
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        label: j['label'] as String? ?? '',
        gain: (j['gain'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind.name, 'startMs': startMs, 'endMs': endMs, 'label': label, 'gain': gain};
}

class Timeline {
  const Timeline({
    required this.durationMs,
    required this.clips,
    required this.captions,
    required this.effects,
    required this.audio,
    this.settings = const EditSettings(),
  });

  final int durationMs;
  final List<Clip> clips;
  final List<CaptionCue> captions;
  final List<EffectLayer> effects;
  final List<AudioLayer> audio;
  final EditSettings settings;

  factory Timeline.fromJson(Map<String, dynamic> j) => Timeline(
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        clips: _list(j['clips'], Clip.fromJson),
        captions: _list(j['captions'], CaptionCue.fromJson),
        effects: _list(j['effects'], EffectLayer.fromJson),
        audio: _list(j['audio'], AudioLayer.fromJson),
        settings: j['settings'] == null
            ? const EditSettings()
            : EditSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
      );

  Map<String, dynamic> toJson() => {
        'durationMs': durationMs,
        'clips': clips.map((e) => e.toJson()).toList(),
        'captions': captions.map((e) => e.toJson()).toList(),
        'effects': effects.map((e) => e.toJson()).toList(),
        'audio': audio.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  static const empty = Timeline(durationMs: 0, clips: [], captions: [], effects: [], audio: []);

  Timeline copyWith({
    int? durationMs,
    List<Clip>? clips,
    List<CaptionCue>? captions,
    List<EffectLayer>? effects,
    List<AudioLayer>? audio,
    EditSettings? settings,
  }) =>
      Timeline(
        durationMs: durationMs ?? this.durationMs,
        clips: clips ?? this.clips,
        captions: captions ?? this.captions,
        effects: effects ?? this.effects,
        audio: audio ?? this.audio,
        settings: settings ?? this.settings,
      );

  /// Total timeline duration after per-clip speed is applied.
  int get playbackDurationMs => clips.isEmpty
      ? durationMs
      : clips.fold(0, (sum, c) => sum + c.playbackMs);

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) =>
      ((raw as List?) ?? const []).map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();

  /// Build a timeline from a real transcript. Captions are derived from the
  /// transcript segments; clips/effects/audio are heuristically mocked so the
  /// editor has multiple tracks to show (Phase 1).
  factory Timeline.fromTranscript(Transcript transcript, {required int fallbackDurationMs}) {
    final durationMs = transcript.duration > 0
        ? (transcript.duration * 1000).round()
        : fallbackDurationMs;

    final captions = <CaptionCue>[
      for (final s in transcript.segments)
        CaptionCue(
          id: 'cap_${s.id}',
          startMs: (s.start * 1000).round(),
          endMs: (s.end * 1000).round(),
          text: s.text,
        ),
    ];

    // One clip per transcript segment (smart-cut stand-in), or a single clip
    // spanning the whole media when there's no speech.
    final clips = captions.isEmpty
        ? [Clip(id: 'clip_0', startMs: 0, endMs: durationMs, label: 'Full clip')]
        : [
            for (var i = 0; i < captions.length; i++)
              Clip(
                id: 'clip_$i',
                startMs: captions[i].startMs,
                endMs: captions[i].endMs,
                label: 'Scene ${i + 1}',
              ),
          ];

    final effects = <EffectLayer>[
      if (durationMs > 0)
        EffectLayer(
          id: 'fx_hook',
          kind: EffectKind.zoom,
          startMs: 0,
          endMs: (durationMs * 0.12).round(),
          label: 'Hook zoom',
        ),
      if (captions.length > 1)
        EffectLayer(
          id: 'fx_transition',
          kind: EffectKind.transition,
          startMs: captions[0].endMs,
          endMs: captions[0].endMs + 400,
          label: 'Smooth cut',
        ),
      EffectLayer(
        id: 'fx_color',
        kind: EffectKind.colorGrade,
        startMs: 0,
        endMs: durationMs,
        label: 'Cinematic LUT',
      ),
    ];

    final audio = <AudioLayer>[
      AudioLayer(
        id: 'aud_music',
        kind: AudioKind.music,
        startMs: 0,
        endMs: durationMs,
        label: 'Upbeat track',
        gain: 0.4,
      ),
      AudioLayer(
        id: 'aud_voice',
        kind: AudioKind.voice,
        startMs: 0,
        endMs: durationMs,
        label: 'Original voice',
      ),
    ];

    return Timeline(
      durationMs: durationMs,
      clips: clips,
      captions: captions,
      effects: effects,
      audio: audio,
    );
  }
}
