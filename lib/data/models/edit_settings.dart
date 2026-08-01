import 'dart:math' as math;

/// All non-destructive edit parameters applied to the timeline. Each maps to a
/// real FFmpeg filter on export and (for visual ones) a live preview transform.

enum FilterPreset { none, cinematic, vintage, warm, cool, bw, vivid, fade }

enum TransitionType { none, fade, dissolve, wipeLeft, slideUp, circleOpen, zoom }

class ColorAdjust {
  const ColorAdjust({
    this.brightness = 0, // -1..1
    this.contrast = 1, // 0..2
    this.saturation = 1, // 0..2
    this.temperature = 0, // -1(cool)..1(warm)
    this.sharpen = 0, // 0..1
  });

  final double brightness, contrast, saturation, temperature, sharpen;

  bool get isIdentity =>
      brightness == 0 && contrast == 1 && saturation == 1 && temperature == 0 && sharpen == 0;

  ColorAdjust copyWith({double? brightness, double? contrast, double? saturation, double? temperature, double? sharpen}) =>
      ColorAdjust(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        temperature: temperature ?? this.temperature,
        sharpen: sharpen ?? this.sharpen,
      );

  factory ColorAdjust.fromJson(Map<String, dynamic> j) => ColorAdjust(
        brightness: (j['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (j['contrast'] as num?)?.toDouble() ?? 1,
        saturation: (j['saturation'] as num?)?.toDouble() ?? 1,
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
        sharpen: (j['sharpen'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'brightness': brightness, 'contrast': contrast, 'saturation': saturation, 'temperature': temperature, 'sharpen': sharpen};
}

class Effects {
  const Effects({this.blur = 0, this.vignette = 0, this.grain = 0}); // each 0..1
  final double blur, vignette, grain;
  bool get isNone => blur == 0 && vignette == 0 && grain == 0;

  Effects copyWith({double? blur, double? vignette, double? grain}) =>
      Effects(blur: blur ?? this.blur, vignette: vignette ?? this.vignette, grain: grain ?? this.grain);

  factory Effects.fromJson(Map<String, dynamic> j) => Effects(
        blur: (j['blur'] as num?)?.toDouble() ?? 0,
        vignette: (j['vignette'] as num?)?.toDouble() ?? 0,
        grain: (j['grain'] as num?)?.toDouble() ?? 0,
      );
  Map<String, dynamic> toJson() => {'blur': blur, 'vignette': vignette, 'grain': grain};
}

class TextOverlay {
  const TextOverlay({
    required this.id,
    required this.text,
    this.xNorm = 0.5,
    this.yNorm = 0.5,
    this.sizePt = 34,
    this.colorHex = '#FFFFFF',
    this.startMs = 0,
    this.endMs = 0, // <= startMs means "open-ended" → runs to the end of the video
    this.rotationDeg = 0, // clockwise-positive, matches Flutter Transform.rotate
    this.opacity = 1, // 0..1
  });

  final String id;
  final String text;
  final double xNorm, yNorm; // 0..1 centre position
  final double sizePt;
  final String colorHex;
  final int startMs, endMs; // OUTPUT-timeline ms window
  final double rotationDeg;
  final double opacity;

  /// The end time given the timeline's [totalMs]; open-ended text runs to the end.
  int effectiveEndMs(int totalMs) => endMs > startMs ? endMs : totalMs;

  TextOverlay copyWith({
    String? text,
    double? xNorm,
    double? yNorm,
    double? sizePt,
    String? colorHex,
    int? startMs,
    int? endMs,
    double? rotationDeg,
    double? opacity,
  }) =>
      TextOverlay(
        id: id,
        text: text ?? this.text,
        xNorm: xNorm ?? this.xNorm,
        yNorm: yNorm ?? this.yNorm,
        sizePt: sizePt ?? this.sizePt,
        colorHex: colorHex ?? this.colorHex,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        opacity: opacity ?? this.opacity,
      );

  factory TextOverlay.fromJson(Map<String, dynamic> j) => TextOverlay(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        xNorm: (j['xNorm'] as num?)?.toDouble() ?? 0.5,
        yNorm: (j['yNorm'] as num?)?.toDouble() ?? 0.5,
        sizePt: (j['sizePt'] as num?)?.toDouble() ?? 34,
        colorHex: j['colorHex'] as String? ?? '#FFFFFF',
        // Missing keys default to the pre-timing behaviour (full duration, no
        // rotation, opaque) so projects saved before this batch load unchanged.
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        rotationDeg: (j['rotationDeg'] as num?)?.toDouble() ?? 0,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'xNorm': xNorm,
        'yNorm': yNorm,
        'sizePt': sizePt,
        'colorHex': colorHex,
        'startMs': startMs,
        'endMs': endMs,
        'rotationDeg': rotationDeg,
        'opacity': opacity,
      };
}

class AudioSettings {
  const AudioSettings({
    this.volume = 1, // 0..2
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.denoise = false,
    this.voiceEnhance = false,
    this.musicPath,
    this.musicVolume = 0.6,
  });

  final double volume;
  final int fadeInMs, fadeOutMs;
  final bool denoise, voiceEnhance;
  final String? musicPath;
  final double musicVolume;

  AudioSettings copyWith({
    double? volume,
    int? fadeInMs,
    int? fadeOutMs,
    bool? denoise,
    bool? voiceEnhance,
    Object? musicPath = _sentinel,
    double? musicVolume,
  }) =>
      AudioSettings(
        volume: volume ?? this.volume,
        fadeInMs: fadeInMs ?? this.fadeInMs,
        fadeOutMs: fadeOutMs ?? this.fadeOutMs,
        denoise: denoise ?? this.denoise,
        voiceEnhance: voiceEnhance ?? this.voiceEnhance,
        musicPath: musicPath == _sentinel ? this.musicPath : musicPath as String?,
        musicVolume: musicVolume ?? this.musicVolume,
      );

  factory AudioSettings.fromJson(Map<String, dynamic> j) => AudioSettings(
        volume: (j['volume'] as num?)?.toDouble() ?? 1,
        fadeInMs: (j['fadeInMs'] as num?)?.toInt() ?? 0,
        fadeOutMs: (j['fadeOutMs'] as num?)?.toInt() ?? 0,
        denoise: j['denoise'] as bool? ?? false,
        voiceEnhance: j['voiceEnhance'] as bool? ?? false,
        musicPath: j['musicPath'] as String?,
        musicVolume: (j['musicVolume'] as num?)?.toDouble() ?? 0.6,
      );
  Map<String, dynamic> toJson() => {
        'volume': volume,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'denoise': denoise,
        'voiceEnhance': voiceEnhance,
        'musicPath': musicPath,
        'musicVolume': musicVolume,
      };

  static const _sentinel = Object();
}

class Cutout {
  const Cutout({this.enabled = false, this.keyColorHex = '#00FF00', this.similarity = 0.3, this.bgColorHex = '#000000'});
  final bool enabled;
  final String keyColorHex;
  final double similarity; // 0..1
  final String bgColorHex;

  Cutout copyWith({bool? enabled, String? keyColorHex, double? similarity, String? bgColorHex}) => Cutout(
        enabled: enabled ?? this.enabled,
        keyColorHex: keyColorHex ?? this.keyColorHex,
        similarity: similarity ?? this.similarity,
        bgColorHex: bgColorHex ?? this.bgColorHex,
      );

  factory Cutout.fromJson(Map<String, dynamic> j) => Cutout(
        enabled: j['enabled'] as bool? ?? false,
        keyColorHex: j['keyColorHex'] as String? ?? '#00FF00',
        similarity: (j['similarity'] as num?)?.toDouble() ?? 0.3,
        bgColorHex: j['bgColorHex'] as String? ?? '#000000',
      );
  Map<String, dynamic> toJson() =>
      {'enabled': enabled, 'keyColorHex': keyColorHex, 'similarity': similarity, 'bgColorHex': bgColorHex};
}

class EditSettings {
  const EditSettings({
    this.color = const ColorAdjust(),
    this.filter = FilterPreset.none,
    this.effects = const Effects(),
    this.texts = const [],
    this.audio = const AudioSettings(),
    this.transition = TransitionType.none,
    this.transitionMs = 500,
    this.cutout = const Cutout(),
  });

  final ColorAdjust color;
  final FilterPreset filter;
  final Effects effects;
  final List<TextOverlay> texts;
  final AudioSettings audio;
  final TransitionType transition;
  final int transitionMs;
  final Cutout cutout;

  EditSettings copyWith({
    ColorAdjust? color,
    FilterPreset? filter,
    Effects? effects,
    List<TextOverlay>? texts,
    AudioSettings? audio,
    TransitionType? transition,
    int? transitionMs,
    Cutout? cutout,
  }) =>
      EditSettings(
        color: color ?? this.color,
        filter: filter ?? this.filter,
        effects: effects ?? this.effects,
        texts: texts ?? this.texts,
        audio: audio ?? this.audio,
        transition: transition ?? this.transition,
        transitionMs: transitionMs ?? this.transitionMs,
        cutout: cutout ?? this.cutout,
      );

  factory EditSettings.fromJson(Map<String, dynamic> j) => EditSettings(
        color: j['color'] == null ? const ColorAdjust() : ColorAdjust.fromJson(Map<String, dynamic>.from(j['color'] as Map)),
        filter: FilterPreset.values.firstWhere((f) => f.name == j['filter'], orElse: () => FilterPreset.none),
        effects: j['effects'] == null ? const Effects() : Effects.fromJson(Map<String, dynamic>.from(j['effects'] as Map)),
        texts: ((j['texts'] as List?) ?? const [])
            .map((e) => TextOverlay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        audio: j['audio'] == null ? const AudioSettings() : AudioSettings.fromJson(Map<String, dynamic>.from(j['audio'] as Map)),
        transition: TransitionType.values.firstWhere((t) => t.name == j['transition'], orElse: () => TransitionType.none),
        transitionMs: (j['transitionMs'] as num?)?.toInt() ?? 500,
        cutout: j['cutout'] == null ? const Cutout() : Cutout.fromJson(Map<String, dynamic>.from(j['cutout'] as Map)),
      );

  Map<String, dynamic> toJson() => {
        'color': color.toJson(),
        'filter': filter.name,
        'effects': effects.toJson(),
        'texts': texts.map((t) => t.toJson()).toList(),
        'audio': audio.toJson(),
        'transition': transition.name,
        'transitionMs': transitionMs,
        'cutout': cutout.toJson(),
      };

  /// The colour adjust with the active filter preset folded in — used by both
  /// the ffmpeg export and the live preview matrix so they stay consistent.
  ColorAdjust get effectiveColor {
    var c = color;
    switch (filter) {
      case FilterPreset.none:
        break;
      case FilterPreset.cinematic:
        c = c.copyWith(contrast: c.contrast * 1.15, saturation: c.saturation * 0.92, temperature: c.temperature + 0.06);
      case FilterPreset.vintage:
        c = c.copyWith(contrast: c.contrast * 0.9, saturation: c.saturation * 0.8, temperature: c.temperature + 0.18, brightness: c.brightness + 0.03);
      case FilterPreset.warm:
        c = c.copyWith(temperature: c.temperature + 0.28);
      case FilterPreset.cool:
        c = c.copyWith(temperature: c.temperature - 0.28);
      case FilterPreset.bw:
        c = c.copyWith(saturation: 0);
      case FilterPreset.vivid:
        c = c.copyWith(saturation: c.saturation * 1.3, contrast: c.contrast * 1.08);
      case FilterPreset.fade:
        c = c.copyWith(contrast: c.contrast * 0.85, saturation: c.saturation * 0.9, brightness: c.brightness + 0.06);
    }
    return c;
  }

  /// 4×5 colour matrix for Flutter's [ColorFilter.matrix] live preview.
  List<double> previewMatrix() {
    final c = effectiveColor;
    var m = _identity;
    m = _compose(_saturationM(c.saturation), m);
    m = _compose(_contrastM(c.contrast), m);
    m = _compose(_temperatureM(c.temperature), m);
    m = _compose(_brightnessM(c.brightness), m);
    return m;
  }

  static const _identity = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

  static List<double> _saturationM(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final ir = (1 - s);
    return [
      ir * lr + s, ir * lg, ir * lb, 0, 0,
      ir * lr, ir * lg + s, ir * lb, 0, 0,
      ir * lr, ir * lg, ir * lb + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static List<double> _contrastM(double c) {
    final o = 127.5 * (1 - c);
    return [c, 0, 0, 0, o, 0, c, 0, 0, o, 0, 0, c, 0, o, 0, 0, 0, 1, 0];
  }

  static List<double> _brightnessM(double b) {
    final o = b * 255;
    return [1, 0, 0, 0, o, 0, 1, 0, 0, o, 0, 0, 1, 0, o, 0, 0, 0, 1, 0];
  }

  static List<double> _temperatureM(double t) {
    final r = 1 + 0.2 * t, b = 1 - 0.2 * t;
    return [r, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0];
  }

  /// result = apply [b] then [a]  (both 4×5, implicit 5th row [0,0,0,0,1]).
  static List<double> _compose(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[i * 5 + k] * b[k * 5 + j];
        }
        if (j == 4) sum += a[i * 5 + 4];
        out[i * 5 + j] = sum;
      }
    }
    return out;
  }

  /// Preview blur sigma in logical px for [ImageFiltered].
  double get previewBlurSigma => effects.blur * 8;

  static double clamp01(double v) => math.max(0, math.min(1, v));
}
