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
  }) async {
    try {
      final headers = <String, dynamic>{};
      if (etag != null && etag.isNotEmpty) {
        headers['If-None-Match'] = etag;
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        headers['X-Device-Id'] = deviceId;
      }

      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/v1/timetable',
        queryParameters: {'termId': termId},
        options: Options(headers: headers),
      );

      if (response.data == null) {
        throw const ServerException(
          AppStrings.errorServer,
          details: 'Empty response body from timetable endpoint',
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
