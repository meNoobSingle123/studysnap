import 'package:dio/dio.dart';

/// Pre-configured Dio HTTP client with 10s timeout and logging interceptor.
class DioClient {
  static const Duration timeoutDuration = Duration(seconds: 10);

  final Dio _dio;

  DioClient({Dio? dio, String? baseUrl})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? '',
                connectTimeout: timeoutDuration,
                receiveTimeout: timeoutDuration,
                sendTimeout: timeoutDuration,
                headers: {
                  'Content-Type': 'application/json; charset=UTF-8',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }

  Dio get dio => _dio;
}
