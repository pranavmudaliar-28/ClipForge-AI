import 'timeline.dart';
import 'transcript.dart';

enum ProjectStatus { draft, processing, ready, exported }

/// A user project — the top-level saved entity, persisted to Hive as JSON.
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.sourcePath,
    this.durationMs = 0,
    this.transcript,
    this.timeline = Timeline.empty,
    this.exportPath,
    this.canvasId = 'yt_shorts',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectStatus status;
  final String? sourcePath;
  final int durationMs;
  final Transcript? transcript;
  final Timeline timeline;
  final String? exportPath;
  final String canvasId;

  Project copyWith({
    String? title,
    DateTime? updatedAt,
    ProjectStatus? status,
    String? sourcePath,
    int? durationMs,
    Transcript? transcript,
    Timeline? timeline,
    String? exportPath,
    String? canvasId,
  }) {
    return Project(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      sourcePath: sourcePath ?? this.sourcePath,
      durationMs: durationMs ?? this.durationMs,
      transcript: transcript ?? this.transcript,
      timeline: timeline ?? this.timeline,
      exportPath: exportPath ?? this.exportPath,
      canvasId: canvasId ?? this.canvasId,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime(2020),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime(2020),
        status: ProjectStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ProjectStatus.draft,
        ),
        sourcePath: json['sourcePath'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        transcript: json['transcript'] == null
            ? null
            : Transcript.fromJson(Map<String, dynamic>.from(json['transcript'] as Map)),
        timeline: json['timeline'] == null
            ? Timeline.empty
            : Timeline.fromJson(Map<String, dynamic>.from(json['timeline'] as Map)),
        exportPath: json['exportPath'] as String?,
        canvasId: json['canvasId'] as String? ?? 'yt_shorts',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'sourcePath': sourcePath,
        'durationMs': durationMs,
        'transcript': transcript?.toJson(),
        'timeline': timeline.toJson(),
        'exportPath': exportPath,
        'canvasId': canvasId,
      };
}
