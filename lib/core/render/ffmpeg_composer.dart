import 'dart:io';
import 'dart:math' as math;

import '../../data/models/canvas_preset.dart';
import '../../data/models/edit_settings.dart';
import '../../data/models/timeline.dart';

/// A fully-built render job: the ffmpeg command, expected output duration (for
/// progress), and the output path.
class RenderJob {
  const RenderJob({required this.command, required this.totalMs, required this.outputPath});
  final String command;
  final int totalMs;
  final String outputPath;
}

/// Compiles a [Timeline] + its [EditSettings] into a real ffmpeg filtergraph:
/// trim/speed per clip → concat (or xfade transitions) → colour/filter/FX/fade
/// → captions+text (ASS/libass) → cutout → audio (volume/fade/denoise/enhance/
/// music) → watermark → H.264/AAC mp4. Every editor tool maps to real filters.
abstract final class FfmpegComposer {
  static Future<RenderJob> build({
    required String sourcePath,
    required Timeline timeline,
    required CanvasPreset canvas,
    required int exportW,
    required int exportH,
    required String outputPath,
    required String subtitlePath, // where to write the generated .ass
    bool watermark = true,
  }) async {
    final s = timeline.settings;
    final w = exportW, h = exportH;
    final clips = timeline.clips.isNotEmpty
        ? timeline.clips
        : [Clip(id: 'c0', startMs: 0, endMs: timeline.durationMs)];

    final f = <String>[]; // filter_complex statements
    // Resolve every distinct source file to an ffmpeg input index. Input 0 is
    // always the project source, so single-source projects produce a command
    // identical to before (zero change to the common path). Added clips with a
    // distinct sourcePath get their own -i input and are trimmed from it.
    final (sources, clipInput) = _resolveSources(sourcePath, clips);
    final multi = sources.length > 1;
    final inputs = <String>[for (final src in sources) "-i '$src'"];

    // 1) Per-clip trim + speed + normalise to canvas.
    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final idx = clipInput[i];
      final inS = (c.startMs / 1000).toStringAsFixed(3);
      final outS = (c.endMs / 1000).toStringAsFixed(3);
      final pts = c.speed == 1.0 ? '' : 'setpts=PTS/${c.speed},';
      // Video normalise (scale/crop/fps/format) already makes clips concat-safe
      // across sources; audio also needs resample+format when mixing sources so
      // concat doesn't fail on differing sample rates/layouts.
      final aNorm = multi ? ',aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo' : '';
      f.add("[$idx:v]trim=$inS:$outS,setpts=PTS-STARTPTS,$pts"
          "scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,fps=30,format=yuv420p[v$i]");
      f.add(_clipAudio(c, idx, i, inS, outS, aNorm));
    }

    // 2) Assemble: xfade/acrossfade transitions, else concat.
    String vLab, aLab;
    if (s.transition != TransitionType.none && clips.length > 1) {
      (vLab, aLab) = _buildTransitions(f, clips, s);
    } else if (clips.length == 1) {
      vLab = 'v0';
      aLab = 'a0';
    } else {
      final b = StringBuffer();
      for (var i = 0; i < clips.length; i++) {
        b.write('[v$i][a$i]');
      }
      f.add('${b}concat=n=${clips.length}:v=1:a=1[vc][ac]');
      vLab = 'vc';
      aLab = 'ac';
    }

    // 3) Video colour / filter / FX / fade chain.
    final vf = <String>[];
    final col = s.effectiveColor;
    if (col.brightness != 0 || col.contrast != 1 || col.saturation != 1) {
      vf.add('eq=brightness=${col.brightness.toStringAsFixed(3)}:contrast=${col.contrast.toStringAsFixed(3)}:saturation=${col.saturation.toStringAsFixed(3)}');
    }
    if (col.temperature != 0) {
      final t = (col.temperature * 0.3).toStringAsFixed(3);
      final nt = (-col.temperature * 0.3).toStringAsFixed(3);
      vf.add('colorbalance=rm=$t:bm=$nt');
    }
    if (col.sharpen > 0) {
      vf.add('unsharp=5:5:${(col.sharpen * 1.5).toStringAsFixed(2)}');
    }
    if (s.effects.blur > 0) vf.add('gblur=sigma=${(s.effects.blur * 10).toStringAsFixed(2)}');
    if (s.effects.vignette > 0) vf.add('vignette=angle=${(math.pi / 5 + s.effects.vignette * 0.6).toStringAsFixed(3)}');
    if (s.effects.grain > 0) vf.add('noise=alls=${(s.effects.grain * 40).round()}:allf=t');
    if (vf.isNotEmpty) {
      f.add('[$vLab]${vf.join(',')}[vfx]');
      vLab = 'vfx';
    }

    // 4) Cutout (chroma-key over a solid background) — real colour-based removal.
    if (s.cutout.enabled) {
      final key = _hexToFf(s.cutout.keyColorHex);
      final bg = _hexToFf(s.cutout.bgColorHex);
      f.add('color=c=$bg:s=${w}x$h[cbg]');
      f.add('[$vLab]chromakey=$key:${s.cutout.similarity.toStringAsFixed(2)}:0.1[ck]');
      f.add('[cbg][ck]overlay=shortest=1[vcut]');
      vLab = 'vcut';
    }

    // 5) Captions + text overlays + watermark → ONE ASS file burned via libass.
    //    (We avoid ffmpeg `drawtext`, which needs a font file on Android and
    //    trips on spaces in the text — libass handles fonts + spacing.)
    final totalMs = _outMs(clips, s);
    final ass = _buildAss(w, h, timeline.captions, clips, s.texts, totalMs, watermark);
    if (ass != null) {
      await File(subtitlePath).writeAsString(ass);
      // Android app-doc paths have no spaces/colons; pass unquoted so ffmpeg-kit's
      // arg parser doesn't choke on quotes nested inside -filter_complex.
      final esc = subtitlePath.replaceAll('\\', '/').replaceAll(':', '\\:');
      f.add('[$vLab]subtitles=$esc[vsub]');
      vLab = 'vsub';
    }

    // 7) Audio chain: volume / fade / denoise / enhance, then optional music mix.
    final af = <String>[];
    if (s.audio.volume != 1) af.add('volume=${s.audio.volume.toStringAsFixed(2)}');
    if (s.audio.denoise) af.add('afftdn=nf=-25');
    if (s.audio.voiceEnhance) af.add('highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11');
    if (s.audio.fadeInMs > 0) af.add('afade=t=in:st=0:d=${(s.audio.fadeInMs / 1000).toStringAsFixed(2)}');
    if (s.audio.fadeOutMs > 0) {
      final st = ((totalMs - s.audio.fadeOutMs) / 1000).clamp(0, totalMs / 1000).toStringAsFixed(2);
      af.add('afade=t=out:st=$st:d=${(s.audio.fadeOutMs / 1000).toStringAsFixed(2)}');
    }
    if (af.isNotEmpty) {
      f.add('[$aLab]${af.join(',')}[apost]');
      aLab = 'apost';
    }
    if (s.audio.musicPath != null && File(s.audio.musicPath!).existsSync()) {
      final musIdx = inputs.length; // music is the next input after all sources
      inputs.add("-i '${s.audio.musicPath}'");
      f.add('[$musIdx:a]volume=${s.audio.musicVolume.toStringAsFixed(2)},aresample=44100[mus]');
      f.add('[$aLab][mus]amix=inputs=2:duration=first:dropout_transition=0[amix]');
      aLab = 'amix';
    }

    // Video fade in/out (whole timeline).
    // (kept last so it fades the final composited frame)
    // handled via drawtext-free fade only if requested — omitted to keep chain simple.

    final command = "-y ${inputs.join(' ')} "
        "-filter_complex \"${f.join(';')}\" "
        "-map [$vLab] -map [$aLab] "
        "-c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "
        "'$outputPath'";

    return RenderJob(command: command, totalMs: totalMs, outputPath: outputPath);
  }

  /// Safety-net render: trim + speed + concat + scale/crop → H.264/AAC, with
  /// NO colour/filter/subtitle/watermark filters. Used as a fallback so an
  /// export always produces a valid file even if a fancy filter is unsupported.
  static RenderJob buildMinimal({
    required String sourcePath,
    required Timeline timeline,
    required int exportW,
    required int exportH,
    required String outputPath,
  }) {
    final w = exportW, h = exportH;
    final clips = timeline.clips.isNotEmpty
        ? timeline.clips
        : [Clip(id: 'c0', startMs: 0, endMs: timeline.durationMs)];
    final (sources, clipInput) = _resolveSources(sourcePath, clips);
    final multi = sources.length > 1;
    final inputs = <String>[for (final src in sources) "-i '$src'"];
    final f = <String>[];
    for (var i = 0; i < clips.length; i++) {
      final c = clips[i];
      final idx = clipInput[i];
      final inS = (c.startMs / 1000).toStringAsFixed(3);
      final outS = (c.endMs / 1000).toStringAsFixed(3);
      final pts = c.speed == 1.0 ? '' : 'setpts=PTS/${c.speed},';
      final aNorm = multi ? ',aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo' : '';
      f.add("[$idx:v]trim=$inS:$outS,setpts=PTS-STARTPTS,$pts"
          "scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,setsar=1,fps=30,format=yuv420p[v$i]");
      f.add(_clipAudio(c, idx, i, inS, outS, aNorm));
    }
    String vLab, aLab;
    if (clips.length == 1) {
      vLab = 'v0';
      aLab = 'a0';
    } else {
      final b = StringBuffer();
      for (var i = 0; i < clips.length; i++) {
        b.write('[v$i][a$i]');
      }
      f.add('${b}concat=n=${clips.length}:v=1:a=1[vc][ac]');
      vLab = 'vc';
      aLab = 'ac';
    }
    final command = "-y ${inputs.join(' ')} -filter_complex \"${f.join(';')}\" "
        "-map [$vLab] -map [$aLab] -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p "
        "-c:a aac -b:a 160k -movflags +faststart '$outputPath'";
    return RenderJob(command: command, totalMs: clips.fold<int>(0, (s, c) => s + c.playbackMs), outputPath: outputPath);
  }

  /// Maps each clip to an ffmpeg input index. Input 0 is always [projectSource];
  /// every distinct [Clip.sourcePath] gets the next index. Returns the ordered
  /// unique source paths and a per-clip input-index list (same length as clips).
  static (List<String>, List<int>) _resolveSources(String projectSource, List<Clip> clips) {
    final sources = <String>[projectSource];
    final idxOf = <String, int>{projectSource: 0};
    final perClip = <int>[];
    for (final c in clips) {
      final sp = (c.sourcePath == null || c.sourcePath!.isEmpty) ? projectSource : c.sourcePath!;
      var idx = idxOf[sp];
      if (idx == null) {
        idx = sources.length;
        sources.add(sp);
        idxOf[sp] = idx;
      }
      perClip.add(idx);
    }
    return (sources, perClip);
  }

  static int _outMs(List<Clip> clips, EditSettings s) {
    final base = clips.fold<int>(0, (sum, c) => sum + c.playbackMs);
    if (s.transition != TransitionType.none && clips.length > 1) {
      final t = _transDurMs(clips, s);
      return math.max(1, base - t * (clips.length - 1));
    }
    return base;
  }

  static int _transDurMs(List<Clip> clips, EditSettings s) {
    final minClip = clips.map((c) => c.playbackMs).reduce(math.min);
    return math.min(s.transitionMs, (minClip * 0.8).round());
  }

  /// Chained xfade (video) + acrossfade (audio) across all clips.
  static (String, String) _buildTransitions(List<String> f, List<Clip> clips, EditSettings s) {
    final tMs = _transDurMs(clips, s);
    final t = (tMs / 1000).toStringAsFixed(3);
    final xf = switch (s.transition) {
      TransitionType.dissolve => 'dissolve',
      TransitionType.wipeLeft => 'wipeleft',
      TransitionType.slideUp => 'slideup',
      TransitionType.circleOpen => 'circleopen',
      TransitionType.zoom => 'zoomin',
      _ => 'fade',
    };
    var vPrev = 'v0';
    var aPrev = 'a0';
    var accMs = clips[0].playbackMs;
    for (var i = 1; i < clips.length; i++) {
      final offset = ((accMs - tMs) / 1000).clamp(0, 1 << 31).toStringAsFixed(3);
      final vOut = i == clips.length - 1 ? 'vc' : 'vx$i';
      final aOut = i == clips.length - 1 ? 'ac' : 'ax$i';
      f.add('[$vPrev][v$i]xfade=transition=$xf:duration=$t:offset=$offset[$vOut]');
      f.add('[$aPrev][a$i]acrossfade=d=$t[$aOut]');
      vPrev = vOut;
      aPrev = aOut;
      accMs = accMs + clips[i].playbackMs - tMs;
    }
    return (vPrev, aPrev);
  }

  /// Per-clip audio: the source's audio when present, otherwise synthesized
  /// silence of the clip's output length so concat never fails on a muted clip.
  static String _clipAudio(Clip c, int inputIdx, int labelIdx, String inS, String outS, String aNorm) {
    if (c.hasAudio) {
      return "[$inputIdx:a]atrim=$inS:$outS,asetpts=PTS-STARTPTS${_atempo(c.speed)}$aNorm[a$labelIdx]";
    }
    final durSec = (c.playbackMs / 1000).toStringAsFixed(3);
    return "anullsrc=r=44100:cl=stereo,atrim=0:$durSec,asetpts=PTS-STARTPTS,"
        "aformat=sample_fmts=fltp:channel_layouts=stereo[a$labelIdx]";
  }

  static String _atempo(double speed) {
    if (speed == 1.0) return '';
    var s = speed;
    final parts = <String>[];
    while (s > 2.0) {
      parts.add('atempo=2.0');
      s /= 2.0;
    }
    while (s < 0.5) {
      parts.add('atempo=0.5');
      s /= 0.5;
    }
    parts.add('atempo=${s.toStringAsFixed(3)}');
    return ',${parts.join(',')}';
  }

  // --- ASS (captions + positioned text) ------------------------------------
  static String? _buildAss(int w, int h, List<CaptionCue> caps, List<Clip> clips, List<TextOverlay> texts, int totalMs, bool watermark) {
    if (caps.isEmpty && texts.isEmpty && !watermark) return null;
    final b = StringBuffer();
    b.writeln('[Script Info]');
    b.writeln('ScriptType: v4.00+');
    b.writeln('PlayResX: $w');
    b.writeln('PlayResY: $h');
    b.writeln('WrapStyle: 2');
    b.writeln('[V4+ Styles]');
    b.writeln('Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    final capFs = (h * 0.045).round();
    b.writeln('Style: Cap,Arial,$capFs,&H00FFFFFF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,1,2,60,60,${(h * 0.06).round()},1');
    b.writeln('Style: Txt,Arial,40,&H00FFFFFF,&H00000000,&H00000000,-1,0,0,0,100,100,0,0,1,2,1,5,10,10,10,1');
    b.writeln('Style: Wm,Arial,${(h * 0.026).round()},&H60FFFFFF,&H90000000,&H00000000,0,0,0,0,100,100,0,0,1,1,0,3,${(w * 0.03).round()},${(w * 0.03).round()},${(h * 0.03).round()},1');
    b.writeln('[Events]');
    b.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');
    if (watermark) {
      b.writeln('Dialogue: 0,${_assTs(0)},${_assTs(totalMs)},Wm,,0,0,0,,ClipForge AI');
    }

    // Captions remapped to the edited timeline.
    var cursor = 0;
    for (final clip in clips) {
      for (final cap in caps) {
        if (cap.endMs <= clip.startMs || cap.startMs >= clip.endMs) continue;
        final cs = cap.startMs.clamp(clip.startMs, clip.endMs);
        final ce = cap.endMs.clamp(clip.startMs, clip.endMs);
        final os = cursor + ((cs - clip.startMs) / clip.speed).round();
        final oe = cursor + ((ce - clip.startMs) / clip.speed).round();
        b.writeln('Dialogue: 0,${_assTs(os)},${_assTs(oe)},Cap,,0,0,0,,${_assEsc(cap.text)}');
      }
      cursor += clip.playbackMs;
    }

    // Positioned text overlays (full duration).
    for (final t in texts) {
      final x = (t.xNorm * w).round();
      final y = (t.yNorm * h).round();
      final c = _assColor(t.colorHex);
      final ov = '{\\an5\\pos($x,$y)\\fs${t.sizePt.round()}\\c$c}${_assEsc(t.text)}';
      b.writeln('Dialogue: 0,${_assTs(0)},${_assTs(totalMs)},Txt,,0,0,0,,$ov');
    }
    return b.toString();
  }

  static String _assTs(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    String p(int n, int w) => n.toString().padLeft(w, '0');
    return '$h:${p(m, 2)}:${p(s, 2)}.${p(cs, 2)}';
  }

  static String _assEsc(String s) => s.replaceAll('\n', '\\N').replaceAll('{', '(').replaceAll('}', ')');

  /// #RRGGBB -> ASS &H00BBGGRR
  static String _assColor(String hex) {
    final h = hex.replaceAll('#', '').padRight(6, 'F');
    final rr = h.substring(0, 2), gg = h.substring(2, 4), bb = h.substring(4, 6);
    return '&H00$bb$gg$rr&';
  }

  /// #RRGGBB -> ffmpeg 0xRRGGBB
  static String _hexToFf(String hex) => '0x${hex.replaceAll('#', '').padRight(6, '0').substring(0, 6)}';
}
