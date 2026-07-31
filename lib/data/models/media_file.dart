/// Where a piece of source media came from.
enum MediaSource { gallery, camera, files, drive, dropbox, oneDrive, sample }

/// A raw source video the user selected/recorded.
class MediaFile {
  const MediaFile({
    required this.path,
    required this.filename,
    required this.source,
    this.sizeBytes = 0,
    this.durationMs = 0,
  });

  final String path;
  final String filename;
  final MediaSource source;
  final int sizeBytes;
  final int durationMs;

  MediaFile copyWith({int? durationMs, int? sizeBytes}) => MediaFile(
        path: path,
        filename: filename,
        source: source,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        durationMs: durationMs ?? this.durationMs,
      );

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
        path: json['path'] as String? ?? '',
        filename: json['filename'] as String? ?? 'clip.mp4',
        source: MediaSource.values.firstWhere(
          (s) => s.name == json['source'],
          orElse: () => MediaSource.files,
        ),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'path': path,
        'filename': filename,
        'source': source.name,
        'sizeBytes': sizeBytes,
        'durationMs': durationMs,
      };
}
