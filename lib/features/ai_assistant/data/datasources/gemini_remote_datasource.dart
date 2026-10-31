import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/security/key_storage_service.dart';

abstract class GeminiRemoteDataSource {
  Future<String> generateContent({
    required String prompt,
    String? explicitApiKey,
  });

  Future<bool> hasApiKey();
  Future<void> saveApiKey(String key);
  Future<String?> getApiKey();
}

class GeminiRemoteDataSourceImpl implements GeminiRemoteDataSource {
  static const List<String> _flashModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-flash-lite-latest',
  ];
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  // Key truyền qua --dart-define=GEMINI_API_KEY=... khi build/run
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final DioClient dioClient;
  final KeyStorageService keyStorageService;

  GeminiRemoteDataSourceImpl({
    required this.dioClient,
    required this.keyStorageService,
  });

  @override
  Future<String?> getApiKey() async {
    if (_envApiKey.isNotEmpty) {
      return _envApiKey;
    }
    return keyStorageService.getGeminiApiKey();
  }

  @override
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  @override
  Future<void> saveApiKey(String key) async {
    await keyStorageService.saveGeminiApiKey(key);
  }

  @override
  Future<String> generateContent({
    required String prompt,
    String? explicitApiKey,
  }) async {
    final apiKey = explicitApiKey ?? await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception(
        'Chưa cấu hình API Key Trợ lý AI. Vui lòng kiểm tra lại cấu hình.',
      );
    }

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 2048,
      }
    };

    dynamic lastErr;
    for (final model in _flashModels) {
      try {
        return await _callModel(
          model: model,
          apiKey: apiKey.trim(),
          requestBody: requestBody,
        );
      } catch (e) {
        lastErr = e;
        // Thử model Flash tiếp theo nếu model trước đó không khả dụng
        continue;
      }
    }
    throw lastErr ?? Exception('Không thể kết nối đến Trợ lý AI Flash.');
  }

  Future<String> _callModel({
    required String model,
    required String apiKey,
    required Map<String, dynamic> requestBody,
  }) async {
    final url = '$_baseUrl/$model:generateContent?key=$apiKey';

    try {
      final response = await dioClient.dio.post(
        url,
        data: jsonEncode(requestBody),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final firstCandidate = candidates.first as Map<String, dynamic>;
          final content = firstCandidate['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final firstPart = parts.first as Map<String, dynamic>;
            final text = firstPart['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text;
            }
          }
        }
        throw Exception('Không nhận được nội dung trả về từ AI.');
      } else {
        throw Exception('Lỗi máy chủ Google AI: ${response.statusCode}');
      }
    } on DioException catch (dioErr) {
      if (dioErr.type == DioExceptionType.connectionTimeout ||
          dioErr.type == DioExceptionType.receiveTimeout ||
          dioErr.type == DioExceptionType.connectionError) {
        throw Exception(
          'Không có kết nối Internet. Vui lòng kiểm tra lại mạng Wifi/4G để dùng Trợ lý AI.',
        );
      }

      final statusCode = dioErr.response?.statusCode;
      if (statusCode == 400 || statusCode == 403 || statusCode == 401) {
        throw Exception(
          'Khóa API Key không hợp lệ hoặc đã hết hạn. Vui lòng kiểm tra lại key.',
        );
      } else if (statusCode == 429) {
        throw Exception(
          'Đã vượt quá hạn mức gọi AI miễn phí (Rate limit). Vui lòng thử lại sau 30 giây.',
        );
      }

      throw Exception('Lỗi kết nối AI: ${dioErr.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Lỗi phân tích AI: $e');
    }
  }
}
