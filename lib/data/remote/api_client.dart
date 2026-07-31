import 'package:dio/dio.dart';

/// Configures the Dio client that talks to the FastAPI worker.
///
/// Uses `localhost:8000`, which works on both a **physical device** and the
/// **emulator** when the host forwards the port once:
///
///   adb reverse tcp:8000 tcp:8000
///
/// (No LAN IP needed — the device's localhost:8000 is tunnelled to the host's
/// backend over USB.) For a device on the same Wi-Fi without adb, pass the
/// host's LAN IP via [overrideBaseUrl]. The old emulator-only alias was
/// `http://10.0.2.2:8000`.
class ApiClient {
  ApiClient({String? overrideBaseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: overrideBaseUrl ?? resolveBaseUrl(),
            connectTimeout: const Duration(seconds: 10),
            // Transcription can be slow (model download + CPU inference), so
            // give the receive side a generous window.
            receiveTimeout: const Duration(minutes: 15),
            sendTimeout: const Duration(minutes: 5),
          ),
        );

  final Dio dio;

  static String resolveBaseUrl() {
    // localhost works on device, emulator, and web once the host forwards the
    // port: `adb reverse tcp:8000 tcp:8000`.
    return 'http://localhost:8000';
  }

  Future<bool> health() async {
    try {
      final res = await dio.get('/health');
      return res.statusCode == 200 && res.data is Map && res.data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }
}
