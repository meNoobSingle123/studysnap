import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nhom_7/core/errors/app_exception.dart';
import 'package:nhom_7/core/network/dio_client.dart';
import 'package:nhom_7/features/timetable/data/datasources/timetable_remote_data_source.dart';

class MockDio extends Mock implements Dio {}

class MockDioClient extends Mock implements DioClient {}

void main() {
  late MockDio mockDio;
  late MockDioClient mockDioClient;
  late TimetableRemoteDataSource remoteDataSource;

  setUp(() {
    mockDio = MockDio();
    mockDioClient = MockDioClient();
    when(() => mockDioClient.dio).thenReturn(mockDio);
    remoteDataSource = TimetableRemoteDataSourceImpl(dioClient: mockDioClient);
  });

  final dummyTimetableResponse = {
    'termId': '2026-1',
    'etag': 'w/"sample_etag"',
    'subjects': [
      {
        'id': 'sub-001',
        'code': 'CS301',
        'name': 'Lập trình di động',
        'credits': 3,
        'colorArgb': 4282557941,
      }
    ],
    'slots': [
      {
        'id': 'slot-001',
        'subjectId': 'sub-001',
        'dayOfWeek': 2,
        'startMin': 450,
        'endMin': 540,
        'room': 'A2-301',
        'buildingId': 'bld-campus-a',
        'source': 'system',
      }
    ],
  };

  final dummyExamsResponse = {
    'termId': '2026-1',
    'exams': [
      {
        'id': 'exam-001',
        'subjectId': 'sub-001',
        'subjectName': 'Lập trình di động',
        'date': '2026-12-20',
        'startTime': '07:30',
        'room': 'A2-301',
        'seatNumber': 'S-24',
        'examType': 'final',
      }
    ],
  };

  final dummyBuildingsResponse = {
    'buildings': [
      {
        'id': 'bld-campus-a',
        'name': 'Tòa nhà A',
        'code': 'A',
        'latitude': 10.8018,
        'longitude': 106.7145,
        'radiusMeters': 50,
      }
    ],
  };

  group('getTimetable', () {
    test('returns timetable data when request succeeds', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/timetable',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/timetable'),
          data: dummyTimetableResponse,
          statusCode: 200,
        ),
      );

      final result = await remoteDataSource.getTimetable(
        '2026-1',
        etag: 'w/"test"',
        deviceId: 'device-123',
      );

      expect(result, equals(dummyTimetableResponse));
      verify(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/timetable',
          queryParameters: {'termId': '2026-1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('throws ServerException when response body is null', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/timetable',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/timetable'),
          data: null,
          statusCode: 200,
        ),
      );

      expect(
        () => remoteDataSource.getTimetable('2026-1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('throws NetworkException on connection timeout', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/timetable',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/timetable'),
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        ),
      );

      expect(
        () => remoteDataSource.getTimetable('2026-1'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('throws ServerException on 500 bad response', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/timetable',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/timetable'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/v1/timetable'),
            statusCode: 500,
            data: {'error': 'Internal server error'},
          ),
        ),
      );

      expect(
        () => remoteDataSource.getTimetable('2026-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('getExams', () {
    test('returns exam data when request succeeds', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/exams',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/exams'),
          data: dummyExamsResponse,
          statusCode: 200,
        ),
      );

      final result = await remoteDataSource.getExams('2026-1', deviceId: 'dev-1');

      expect(result, equals(dummyExamsResponse));
      verify(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/exams',
          queryParameters: {'termId': '2026-1'},
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('throws NetworkException on receive timeout', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/exams',
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/exams'),
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout',
        ),
      );

      expect(
        () => remoteDataSource.getExams('2026-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('getCampusBuildings', () {
    test('returns buildings data when request succeeds', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/campus/buildings',
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/v1/campus/buildings'),
          data: dummyBuildingsResponse,
          statusCode: 200,
        ),
      );

      final result = await remoteDataSource.getCampusBuildings();

      expect(result, equals(dummyBuildingsResponse));
      verify(() => mockDio.get<Map<String, dynamic>>('/v1/campus/buildings'))
          .called(1);
    });

    test('throws ServerException on 404 bad response', () async {
      when(
        () => mockDio.get<Map<String, dynamic>>(
          '/v1/campus/buildings',
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/v1/campus/buildings'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/v1/campus/buildings'),
            statusCode: 404,
            data: {'error': 'Buildings not found'},
          ),
        ),
      );

      expect(
        () => remoteDataSource.getCampusBuildings(),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
