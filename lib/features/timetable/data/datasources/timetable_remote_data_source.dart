import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/network/dio_client.dart';

/// Giao diện Remote DataSource cho phân hệ Thời khóa biểu theo đặc tả Chương 5.
abstract class TimetableRemoteDataSource {
  /// Kéo thời khóa biểu ca học theo học kỳ [termId] (GET /v1/timetable?termId=)
  Future<Map<String, dynamic>> getTimetable(
    String termId, {
    String? etag,
    String? deviceId,
    String? serverUrl,
  });

  /// Lấy danh sách lịch thi theo học kỳ [termId] (GET /v1/exams?termId=)
  Future<Map<String, dynamic>> getExams(
    String termId, {
    String? deviceId,
  });

  /// Lấy danh sách tòa nhà và tọa độ khuôn viên (GET /v1/campus/buildings)
  Future<Map<String, dynamic>> getCampusBuildings();
}

/// Triển khai Remote DataSource sử dụng [DioClient] chuẩn Clean Architecture.
class TimetableRemoteDataSourceImpl implements TimetableRemoteDataSource {
  final DioClient dioClient;

  TimetableRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<Map<String, dynamic>> getTimetable(
    String termId, {
    String? etag,
    String? deviceId,
    String? serverUrl,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        headers['X-Device-Id'] = deviceId;
      }

      String targetUrl = '/v1/timetable';
      Map<String, dynamic>? queryParams = {'termId': termId};

      final custom = serverUrl?.trim() ?? '';
      if (custom.isNotEmpty) {
        final normalized = custom.endsWith('/')
            ? custom.substring(0, custom.length - 1)
            : custom;
        if (normalized.endsWith('.json') || normalized.contains('/v1/')) {
          targetUrl = normalized;
          if (normalized.endsWith('.json') || normalized.contains('termId=')) {
            queryParams = null;
          }
        } else {
          targetUrl = '$normalized/v1/timetable';
        }
      }

      try {
        final response = await dioClient.dio.get<Map<String, dynamic>>(
          targetUrl,
          queryParameters: queryParams,
          options: Options(headers: headers),
        );

        final payload = response.data;
        if (payload == null) {
          throw const ServerException(
            AppStrings.errorServer,
            details: 'Empty response body from timetable endpoint',
          );
        }

        return payload;
      } on TypeError {
        // Hỗ trợ các link JSON thô trả về Content-Type text/plain
        final rawResp = await dioClient.dio.get<String>(
          targetUrl,
          queryParameters: queryParams,
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
          ),
        );
        final rawText = rawResp.data?.trim() ?? '';
        if (rawText.isEmpty) {
          throw const ServerException(
            AppStrings.errorServer,
            details: 'Empty plain-text response body from timetable endpoint',
          );
        }
        final decoded = jsonDecode(rawText);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw const ServerException(
          AppStrings.errorServer,
          details: 'Invalid JSON format from timetable endpoint',
        );
      }
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(AppStrings.errorUnknown, details: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getExams(
    String termId, {
    String? deviceId,
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (deviceId != null && deviceId.isNotEmpty) {
        headers['X-Device-Id'] = deviceId;
      }

      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/v1/exams',
        queryParameters: {'termId': termId},
        options: Options(headers: headers),
      );

      if (response.data == null) {
        throw const ServerException(
          AppStrings.errorServer,
          details: 'Empty response body from exams endpoint',
        );
      }

      return response.data!;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(AppStrings.errorUnknown, details: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getCampusBuildings() async {
    try {
      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/v1/campus/buildings',
      );

      if (response.data == null) {
        throw const ServerException(
          AppStrings.errorServer,
          details: 'Empty response body from campus buildings endpoint',
        );
      }

      return response.data!;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw NetworkException(AppStrings.errorUnknown, details: e.toString());
    }
  }

  Never _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      throw NetworkException(AppStrings.errorNetwork, details: e.message);
    } else if (e.type == DioExceptionType.badResponse) {
      throw ServerException(
        AppStrings.errorServer,
        code: '${e.response?.statusCode}',
        details: e.response?.data,
      );
    }
    throw NetworkException(AppStrings.errorNetwork, details: e.message);
  }
}
