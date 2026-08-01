/// A visual object composited ON TOP of the base video track. Batch 3 ships
/// [OverlayKind.image] and [OverlayKind.sticker]; [video] (PiP) and [shape]
/// arrive in later batches and reuse this same model + render path.
///
/// Timing is on the OUTPUT timeline (post-concat), so an overlay composites onto
/// the finished base stream via `overlay=...:enable='between(t,start,end)'` and
/// is fully decoupled from the base track's trim/concat/xfade math.
enum OverlayKind { image, sticker, video, shape }

class OverlayObject {
  const OverlayObject({
    required this.id,
    required this.kind,
    required this.sourcePath,
    this.aspect = 1.0, // source width / height (drives on-canvas + gizmo sizing)
    this.startMs = 0,
    this.endMs = 0, // <= startMs ⇒ open-ended (runs to the end of the timeline)
    this.xNorm = 0.5,
    this.yNorm = 0.5, // centre position, 0..1 of the canvas
    this.wNorm = 0.4, // width as a fraction of canvas width (height from aspect)
    this.rotationDeg = 0, // clockwise-positive (matches Flutter Transform.rotate)
    this.opacity = 1,
    this.z = 0, // stacking order (higher = in front)
  });

  final String id;
  final OverlayKind kind;
  final String sourcePath; // image/sticker PNG/JPG on disk
  final double aspect;
  final int startMs, endMs;
  final double xNorm, yNorm, wNorm, rotationDeg, opacity;
  final int z;

  /// The end time given the timeline's [totalMs]; open-ended runs to the end.
  int effectiveEndMs(int totalMs) => endMs > startMs ? endMs : totalMs;

  OverlayObject copyWith({
    OverlayKind? kind,
    String? sourcePath,
    double? aspect,
    int? startMs,
    int? endMs,
    double? xNorm,
    double? yNorm,
    double? wNorm,
    double? rotationDeg,
    double? opacity,
    int? z,
  }) =>
      OverlayObject(
        id: id,
        kind: kind ?? this.kind,
        sourcePath: sourcePath ?? this.sourcePath,
        aspect: aspect ?? this.aspect,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        xNorm: xNorm ?? this.xNorm,
        yNorm: yNorm ?? this.yNorm,
        wNorm: wNorm ?? this.wNorm,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        opacity: opacity ?? this.opacity,
        z: z ?? this.z,
      );

  factory OverlayObject.fromJson(Map<String, dynamic> j) => OverlayObject(
        id: j['id'] as String? ?? '',
        kind: OverlayKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => OverlayKind.image),
        sourcePath: j['sourcePath'] as String? ?? '',
        aspect: (j['aspect'] as num?)?.toDouble() ?? 1.0,
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        endMs: (j['endMs'] as num?)?.toInt() ?? 0,
        xNorm: (j['xNorm'] as num?)?.toDouble() ?? 0.5,
        yNorm: (j['yNorm'] as num?)?.toDouble() ?? 0.5,
        wNorm: (j['wNorm'] as num?)?.toDouble() ?? 0.4,
        rotationDeg: (j['rotationDeg'] as num?)?.toDouble() ?? 0,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
        z: (j['z'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'sourcePath': sourcePath,
        'aspect': aspect,
        'startMs': startMs,
        'endMs': endMs,
        'xNorm': xNorm,
        'yNorm': yNorm,
        'wNorm': wNorm,
        'rotationDeg': rotationDeg,
        'opacity': opacity,
        'z': z,
      };
}
