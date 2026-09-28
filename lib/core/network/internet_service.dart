import 'package:dio/dio.dart';

class InternetService {
  InternetService({
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Lightweight endpoint used only to verify that the phone
  /// can actually reach the public internet.
  ///
  /// Later, when OfflineLink has its own backend, this should
  /// be replaced by our own /health endpoint.
  static const String _probeUrl =
      'https://www.gstatic.com/generate_204';

  Future<bool> hasInternet() async {
    try {
      final response = await _dio.get<void>(
        _probeUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
          validateStatus: (status) {
            return status == 204 ||
                (status != null && status >= 200 && status < 400);
          },
        ),
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _dio.close(force: true);
  }
}