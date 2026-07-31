import 'dart:io';

import 'package:dio/dio.dart';

import '../models/transcript.dart';

/// Calls the backend `/transcribe` endpoint — the real slice of the pipeline.
class TranscriptionService {
  TranscriptionService(this._dio);

  final Dio _dio;

  Future<Transcript> transcribe(File video) async {
    final filename = video.uri.pathSegments.isNotEmpty ? video.uri.pathSegments.last : 'clip.mp4';
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(video.path, filename: filename),
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '/transcribe',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = res.data;
    if (data == null) {
      throw const FormatException('Empty transcription response');
    }
    return Transcript.fromJson(Map<String, dynamic>.from(data));
  }
}
