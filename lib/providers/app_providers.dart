import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/render/export_service.dart';
import '../core/render/ffmpeg_service.dart';
import '../data/local/hive_boxes.dart';
import '../data/local/project_repository.dart';
import '../data/remote/ai_pipeline_service.dart';
import '../data/remote/api_client.dart';
import '../data/remote/transcription_service.dart';

/// Wiring for services + repositories. Hive boxes are opened in `main()` before
/// `runApp`, so [projectRepositoryProvider] can read the box synchronously.

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final transcriptionServiceProvider = Provider<TranscriptionService>(
  (ref) => TranscriptionService(ref.watch(apiClientProvider).dio),
);

final aiPipelineServiceProvider = Provider<AiPipelineService>(
  (ref) => AiPipelineService(ref.watch(transcriptionServiceProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(HiveBoxes.projectsBox),
);

final ffmpegServiceProvider = Provider<FfmpegService>((ref) => FfmpegService());

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(ffmpegServiceProvider)),
);
